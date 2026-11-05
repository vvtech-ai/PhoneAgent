#import "TrustedCallerIncomingSession.h"
#import "TrustedCallerIncomingPayload.h"
#import <math.h>
#import "TrustedCallerIncomingDiagnostics.h"
@interface TrustedIncomingCompletion : NSObject
@property(nonatomic, copy) NSString *eventId;
@property(nonatomic, copy, nullable) void (^callback)(BOOL);
@property(nonatomic) BOOL completed;
- (void)finish:(BOOL)verified;
@end
@implementation TrustedIncomingCompletion
- (void)finish:(BOOL)verified {
    if (self.completed) return;
    self.completed = YES;
    void (^callback)(BOOL) = self.callback;
    self.callback = nil;
    if (callback) callback(verified);
}
@end
@interface TrustedCallerIncomingSession ()
@property(nonatomic, strong) TrustedCallerIncomingDriver *driver;
@property(nonatomic, strong) NSMutableArray<TrustedIncomingCompletion *> *waiting;
@property(nonatomic, copy, nullable) NSDictionary *lastReport;
@property(nonatomic, copy, nullable) TrustedIncomingReport listener;
@property(nonatomic) NSUInteger consumer;
@property(nonatomic) NSUInteger deliveryGeneration;
@property(nonatomic, strong) NSMutableDictionary<NSString *, TrustedIncomingReport> *lifecycleListeners;
@property(nonatomic) BOOL receivedOwner;
@property(nonatomic, copy, nullable) NSDictionary *pendingUserInfo;
@property(nonatomic) NSTimeInterval pendingReceivedAt;
@property(nonatomic) NSUInteger pendingGeneration;
@end
@implementation TrustedCallerIncomingSession
- (instancetype)initWithBootstrap:(TrustedIncomingBootstrap)bootstrap parse:(TrustedIncomingParse)parse {
    if ((self = [super init])) {
        _waiting = [NSMutableArray array];
        _lifecycleListeners = [NSMutableDictionary dictionary];
        __weak typeof(self) weakSelf = self;
        _driver = [[TrustedCallerIncomingDriver alloc] initWithBootstrap:bootstrap parse:parse
            report:^(NSDictionary *report) { [weakSelf publish:report]; }];
    }
    return self;
}
- (void)publish:(NSDictionary *)report {
    if ([report[@"eventId"] isEqual:self.lastReport[@"eventId"]] && self.lastReport[@"presentationRevision"]) {
        NSMutableDictionary *continued = report.mutableCopy;
        continued[@"presentationRevision"] = self.lastReport[@"presentationRevision"];
        report = continued;
    }
    NSUInteger generation = ++self.deliveryGeneration;
    self.lastReport = report.copy;
    NSString *phase = report[@"identity"][@"verification"];
    for (TrustedIncomingCompletion *request in self.waiting.copy) {
        if (!report || ![request.eventId isEqual:report[@"eventId"]]) [request finish:NO];
        else if (![phase isEqual:@"pending"]) [request finish:[phase isEqual:@"verified"] || [phase isEqual:@"uncertified"]];
        if (request.completed) [self.waiting removeObject:request];
    }
    if (generation == self.deliveryGeneration && self.lifecycleReport) self.lifecycleReport(self.lastReport);
    for (TrustedIncomingReport observer in self.lifecycleListeners.allValues.copy) {
        if (generation != self.deliveryGeneration) break;
        observer(self.lastReport);
    }
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingDelivery"
        code:report ? @"IOS_EVENT_PUBLISHED" : @"IOS_EVENT_CLEARED" result:report ? @"received" : @"cancelled"];
    if (generation == self.deliveryGeneration && self.listener) self.listener(self.lastReport);
}
- (void)attachConsumer:(NSUInteger)consumer {
    NSAssert(NSThread.isMainThread, @"Incoming session serialized on main thread");
    if (consumer <= self.consumer) return;
    self.consumer = consumer;
    self.receivedOwner = NO;
    [self clearPendingNotification];
    self.listener = nil;
    [self.driver updateOwner:nil];
    [self publish:nil];
    [self.lifecycleListeners removeAllObjects];
}
- (void)updateOwner:(NSDictionary *)owner consumer:(NSUInteger)consumer {
    [self updateOwner:owner consumer:consumer now:NSDate.date.timeIntervalSince1970];
}
- (void)clearPendingNotification {
    self.pendingGeneration++;
    self.pendingUserInfo = nil;
}
- (void)updateOwner:(NSDictionary *)owner consumer:(NSUInteger)consumer now:(NSTimeInterval)now {
    if (consumer != self.consumer) return;
    NSDictionary *pending = self.pendingUserInfo;
    NSTimeInterval age = now - self.pendingReceivedAt;
    self.receivedOwner = YES;
    [self clearPendingNotification];
    NSUInteger generation = self.pendingGeneration;
    [self.driver updateOwner:owner];
    if (consumer == self.consumer && generation == self.pendingGeneration &&
        owner && pending && isfinite(age) && age >= 0 && age <= 25 &&
        [TrustedCallerIncomingPayload payloadFromUserInfo:pending currentPhone:owner[@"phone"] now:now]) {
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingCache" code:@"IOS_CACHE_RECOVERED" result:@"succeeded"];
        [self.driver receiveUserInfo:pending now:now];
    } else if (pending) {
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingCache"
            code:age > 25 ? @"IOS_CACHE_EXPIRED" : @"IOS_CACHE_REJECTED" result:@"failed"];
    }
}
- (void)listen:(TrustedIncomingReport)report consumer:(NSUInteger)consumer {
    if (consumer != self.consumer) return;
    self.listener = [report copy];
    self.listener(self.lastReport);
}
- (void)cancelListener:(NSUInteger)consumer {
    if (consumer == self.consumer) self.listener = nil;
}
- (BOOL)receiveUserInfo:(NSDictionary *)userInfo now:(NSTimeInterval)now
    consumer:(NSUInteger)consumer completion:(void (^)(BOOL))completion {
    if (consumer != self.consumer) {
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingPayload" code:@"IOS_OWNER_STALE" result:@"failed"];
        return NO;
    }
    if (!self.receivedOwner) {
        if (![userInfo isKindOfClass:NSDictionary.class]) return NO;
        TrustedCallerIncomingPayload *payload = [TrustedCallerIncomingPayload candidateFromUserInfo:userInfo now:now];
        if (!payload) {
            [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingPayload" code:@"IOS_PAYLOAD_REJECTED" result:@"failed"];
            return NO;
        }
        NSMutableDictionary *fields = payload.preview.mutableCopy;
        fields[@"token"] = payload.sdkArguments[@"token"];
        if (payload.avatarURL.length) fields[@"picUrl"] = payload.avatarURL;
        fields[@"dept"] = fields[@"deptZh"];
        fields[@"companyName"] = fields[@"commonName"];
        [fields removeObjectsForKeys:@[@"deptZh", @"commonName", @"signStaus"]];
        self.pendingUserInfo = fields.copy;
        self.pendingReceivedAt = now;
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingCache" code:@"IOS_CACHE_STORED" result:@"received"];
        NSUInteger generation = ++self.pendingGeneration;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (weakSelf && weakSelf.pendingGeneration == generation) {
                [weakSelf clearPendingNotification];
                [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingCache" code:@"IOS_CACHE_EXPIRED" result:@"cancelled"];
            }
        });
        completion(NO);
        return YES;
    }
    if (![self.driver receiveUserInfo:userInfo now:now]) return NO;
    NSDictionary *report = self.lastReport;
    if (consumer != self.consumer || !report) { completion(NO); return YES; }
    NSString *phase = report[@"identity"][@"verification"];
    if (![phase isEqual:@"pending"]) {
        completion([phase isEqual:@"verified"] || [phase isEqual:@"uncertified"]);
        return YES;
    }
    TrustedIncomingCompletion *request = [TrustedIncomingCompletion new];
    request.eventId = report[@"eventId"];
    request.callback = [completion copy];
    [self.waiting addObject:request];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [request finish:NO];
        [weakSelf.waiting removeObject:request];
    });
    return YES;
}
- (BOOL)reopenNotification:(NSDictionary *)userInfo consumer:(NSUInteger)consumer {
    if (consumer != self.consumer || !self.lastReport) return NO;
    NSDictionary *identity = self.lastReport[@"identity"];
    TrustedCallerIncomingPayload *payload = [TrustedCallerIncomingPayload payloadFromUserInfo:userInfo
        currentPhone:self.lastReport[@"owner"][@"phone"] now:NSDate.date.timeIntervalSince1970];
    if (!payload || ![payload.preview[@"phoneno"] isEqual:identity[@"phoneno"]] ||
        ![payload.preview[@"targetNumber"] isEqual:identity[@"targetNumber"]] ||
        ![payload.preview[@"sequence"] isEqual:identity[@"sequence"]]) return NO;
    NSUInteger revision = [self.lastReport[@"presentationRevision"] unsignedIntegerValue];
    if (revision >= INT32_MAX) return NO;
    NSMutableDictionary *report = self.lastReport.mutableCopy;
    report[@"presentationRevision"] = @(revision + 1);
    self.lastReport = report.copy;
    [self publish:report];
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingDelivery" code:@"IOS_EVENT_REOPENED" result:@"succeeded"];
    return YES;
}
- (void)endIncoming:(NSUInteger)consumer {
    if (consumer == self.consumer) { [self clearPendingNotification]; [self.driver endIncoming]; }
}
- (void)endEventId:(NSString *)eventId consumer:(NSUInteger)consumer {
    if (consumer == self.consumer && [self.lastReport[@"eventId"] isEqual:eventId]) {
        [self.driver endIncoming];
    }
}
- (void)setLifecycleListener:(TrustedIncomingReport)listener forKey:(NSString *)key consumer:(NSUInteger)consumer {
    if (consumer != self.consumer || !key.length) return;
    if (!listener) [self.lifecycleListeners removeObjectForKey:key];
    else {
        self.lifecycleListeners[key] = [listener copy];
        listener(self.lastReport);
    }
}
- (BOOL)requestPresentationForEventId:(NSString *)eventId consumer:(NSUInteger)consumer now:(NSTimeInterval)now {
    if (consumer != self.consumer || ![self.lastReport[@"eventId"] isEqual:eventId] ||
        ![@[@"verified", @"uncertified"] containsObject:self.lastReport[@"identity"][@"verification"]] ||
        ![self.lastReport[@"activityFresh"] isEqual:@YES]) return NO;
    NSString *time = self.lastReport[@"identity"][@"callTime"];
    if (![time isKindOfClass:NSString.class] || !time.length ||
        [time rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location != NSNotFound) return NO;
    NSTimeInterval age = now - time.doubleValue / 1000.0;
    if (!isfinite(now) || !isfinite(age) || age < -60 || age > 1200) return NO;
    NSUInteger revision = [self.lastReport[@"presentationRevision"] unsignedIntegerValue];
    if (revision >= INT32_MAX) return NO;
    NSMutableDictionary *report = self.lastReport.mutableCopy;
    report[@"presentationRevision"] = @(revision + 1);
    // Preserve this explicit revision when publish merges ordinary SDK updates.
    self.lastReport = report.copy;
    [self publish:report];
    return YES;
}
@end
