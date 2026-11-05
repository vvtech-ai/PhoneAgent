#import "TrustedCallerCallAssociation.h"
@interface TrustedCallerCallAssociation ()
@property(nonatomic, strong) NSMutableSet<NSString *> *active;
@property(nonatomic, strong) NSMutableSet<NSString *> *claimed;
@property(nonatomic, copy, nullable) NSString *eventId;
@property(nonatomic, copy, nullable) NSString *boundUUID;
@end
@implementation TrustedCallerCallAssociation
- (instancetype)init {
    if ((self = [super init])) {
        _active = [NSMutableSet set];
        _claimed = [NSMutableSet set];
    }
    return self;
}
- (void)associateIfUnambiguous {
    if (!self.eventId || self.boundUUID) return;
    NSMutableSet *available = self.active.mutableCopy;
    [available minusSet:self.claimed];
    if (available.count != 1) return;
    self.boundUUID = available.anyObject;
    [self.claimed addObject:self.boundUUID];
}
- (void)updateEventId:(NSString *)eventId {
    if ([self.eventId isEqual:eventId]) return;
    self.eventId = eventId.length ? eventId.copy : nil;
    self.boundUUID = nil;
    [self associateIfUnambiguous];
}
- (NSString *)observeUUID:(NSString *)uuid outgoing:(BOOL)outgoing ended:(BOOL)ended {
    if (!uuid.length || outgoing) return nil;
    if (ended) {
        [self.active removeObject:uuid];
        [self.claimed removeObject:uuid];
        if (![self.boundUUID isEqual:uuid]) return nil;
        NSString *event = self.eventId;
        self.eventId = nil;
        self.boundUUID = nil;
        return event;
    }
    [self.active addObject:uuid];
    [self associateIfUnambiguous];
    return nil;
}
@end
