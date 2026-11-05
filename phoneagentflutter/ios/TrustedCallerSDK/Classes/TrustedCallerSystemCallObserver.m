#import "TrustedCallerSystemCallObserver.h"
#import "TrustedCallerCallAssociation.h"
#import <CallKit/CallKit.h>
@interface TrustedCallerSystemCallObserver () <CXCallObserverDelegate>
@property(nonatomic, strong) CXCallObserver *observer;
@property(nonatomic, strong) TrustedCallerCallAssociation *association;
@property(nonatomic, weak) TrustedCallerIncomingSession *session;
@property(nonatomic) NSUInteger consumer;
@end
@implementation TrustedCallerSystemCallObserver
- (instancetype)initWithSession:(TrustedCallerIncomingSession *)session consumer:(NSUInteger)consumer {
    if ((self = [super init])) {
        _session = session;
        _consumer = consumer;
        _association = [TrustedCallerCallAssociation new];
        _observer = [CXCallObserver new];
        [_observer setDelegate:self queue:dispatch_get_main_queue()];
        for (CXCall *call in _observer.calls) {
            [_association observeUUID:call.UUID.UUIDString outgoing:call.outgoing ended:call.hasEnded];
        }
        __weak typeof(self) weakSelf = self;
        session.lifecycleReport = ^(NSDictionary *report) {
            [weakSelf.association updateEventId:report[@"eventId"]];
        };
    }
    return self;
}
- (void)callObserver:(CXCallObserver *)observer callChanged:(CXCall *)call {
    NSString *eventId = [self.association observeUUID:call.UUID.UUIDString outgoing:call.outgoing ended:call.hasEnded];
    if (eventId) [self.session endEventId:eventId consumer:self.consumer];
}
- (void)stop {
    [self.observer setDelegate:nil queue:dispatch_get_main_queue()];
    self.session = nil;
}
@end
