#import "TrustedCallerIncomingDriver.h"
#import "TrustedCallerIncomingPayload.h"
#import "TrustedCallerIdentityEvidence.h"
#import <CoreFoundation/CoreFoundation.h>
#import "TrustedCallerIncomingDiagnostics.h"
@interface TrustedCallerIncomingDriver ()
@property(nonatomic, copy) TrustedIncomingBootstrap bootstrap;
@property(nonatomic, copy) TrustedIncomingParse parse;
@property(nonatomic, copy) TrustedIncomingReport report;
@property(nonatomic, copy, nullable) NSDictionary *owner;
@property(nonatomic, copy, nullable) NSArray *eventKey;
@property(nonatomic, copy, nullable) NSString *eventId;
@property(nonatomic) NSUInteger generation;
@end
@implementation TrustedCallerIncomingDriver
- (instancetype)initWithBootstrap:(TrustedIncomingBootstrap)bootstrap
    parse:(TrustedIncomingParse)parse report:(TrustedIncomingReport)report {
    if ((self = [super init])) {
        _bootstrap = [bootstrap copy]; _parse = [parse copy]; _report = [report copy];
    }
    return self;
}
- (void)updateOwner:(NSDictionary *)owner {
    NSAssert(NSThread.isMainThread, @"Incoming identity serialized on main thread");
    NSMutableDictionary *frozen = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"accountId", @"phone", @"loginEpoch", @"environment"]) {
        id value = owner[key];
        if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) frozen[key] = [value copy];
    }
    id epoch = frozen[@"loginEpoch"];
    BOOL valid = frozen.count == 4 && [epoch isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)epoch) != CFBooleanGetTypeID() &&
        strchr("cislqCISLQ", [epoch objCType][0]) != NULL && [epoch longLongValue] >= 0 &&
        ([frozen[@"environment"] isEqual:@"test"] || [frozen[@"environment"] isEqual:@"pro"]);
    for (NSString *key in @[@"accountId", @"phone"]) {
        id value = frozen[key];
        valid = valid && [value isKindOfClass:NSString.class] &&
            [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0 &&
            [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound;
    }
    NSDictionary *next = valid ? frozen.copy : nil;
    if ([self.owner isEqual:next] || (!self.owner && !next)) return;
    self.owner = next;
    [self endIncoming];
}
- (BOOL)current:(NSUInteger)generation owner:(NSDictionary *)owner {
    return generation == self.generation && [self.owner isEqual:owner];
}
- (void)emit:(NSDictionary *)identity owner:(NSDictionary *)owner eventId:(NSString *)eventId fresh:(BOOL)fresh {
    self.report(@{@"owner":owner, @"eventId":eventId, @"identity":identity, @"activityFresh":@(fresh)});
}
- (BOOL)receiveUserInfo:(NSDictionary *)userInfo now:(NSTimeInterval)now {
    NSAssert(NSThread.isMainThread, @"Incoming identity serialized on main thread");
    if (!self.owner) {
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingPayload" code:@"IOS_OWNER_MISSING" result:@"failed"];
        return NO;
    }
    TrustedCallerIncomingPayload *payload = [TrustedCallerIncomingPayload payloadFromUserInfo:userInfo
        currentPhone:self.owner[@"phone"] now:now];
    if (!payload) {
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingPayload" code:@"IOS_PAYLOAD_REJECTED" result:@"failed"];
        return NO;
    }
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingPayload" code:@"IOS_PAYLOAD_ACCEPTED" result:@"succeeded"];
    NSDictionary *owner = self.owner;
    NSArray *eventKey = @[owner, payload.sdkArguments[@"caller"], payload.sdkArguments[@"called"], payload.sdkArguments[@"sequence"]];
    if ([self.eventKey isEqual:eventKey]) {
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingDelivery" code:@"IOS_EVENT_DUPLICATE" result:@"received"];
        return YES;
    }
    self.eventKey = eventKey;
    self.eventId = NSUUID.UUID.UUIDString;
    NSString *eventId = self.eventId;
    NSUInteger generation = ++self.generation;
    NSMutableDictionary *preview = payload.preview.mutableCopy;
    preview[@"verification"] = @"pending";
    [self emit:preview.copy owner:owner eventId:eventId fresh:NO];
    if (![self current:generation owner:owner]) return YES;
    __weak typeof(self) weakSelf = self;
    __block BOOL initializedReply = NO;
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingVerify" code:@"IOS_VERIFY_STARTED" result:@"started"];
    self.bootstrap(^(BOOL success) {
        NSAssert(NSThread.isMainThread, @"SDK incoming callback serialized on main thread");
        if (initializedReply) return;
        initializedReply = YES;
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || ![strongSelf current:generation owner:owner]) return;
        if (!success) {
            [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingVerify" code:@"IOS_VERIFY_FAILED" result:@"failed"];
            [strongSelf emit:[TrustedCallerIdentityEvidence reportForCode:0 data:nil payload:payload]
                owner:owner eventId:eventId fresh:NO];
            return;
        }
        __block BOOL parsedReply = NO;
        strongSelf.parse(payload, ^(NSInteger code, id data) {
            NSAssert(NSThread.isMainThread, @"SDK incoming callback serialized on main thread");
            if (parsedReply) return;
            parsedReply = YES;
            typeof(self) currentSelf = weakSelf;
            if (!currentSelf || ![currentSelf current:generation owner:owner]) return;
            NSDictionary *identity = [TrustedCallerIdentityEvidence reportForCode:code data:data payload:payload];
            BOOL verified = [@[@"verified", @"uncertified"] containsObject:identity[@"verification"]];
            NSString *diagnosticCode = !verified ? @"IOS_VERIFY_FAILED" :
                [identity[@"verification"] isEqual:@"uncertified"] ? @"IOS_VERIFY_UNCERTIFIED" : @"IOS_VERIFY_SUCCEEDED";
            [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingVerify" code:diagnosticCode result:verified ? @"succeeded" : @"failed"];
            [currentSelf emit:identity owner:owner eventId:eventId fresh:verified && payload.activityFresh];
        });
    });
    return YES;
}
- (void)endIncoming {
    NSAssert(NSThread.isMainThread, @"Incoming identity serialized on main thread");
    self.generation++;
    self.eventKey = nil;
    self.eventId = nil;
    self.report(nil);
}
@end
