#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerCallAssociation.h"
int main(void) {
 @autoreleasepool {
    TrustedCallerCallAssociation *state = [TrustedCallerCallAssociation new];
    [state updateEventId:@"A"];
    [state observeUUID:@"outgoing" outgoing:YES ended:NO];
    NSCAssert(![state observeUUID:@"outgoing" outgoing:YES ended:YES], @"Outgoing never clears identity");
    [state observeUUID:@"incoming-A" outgoing:NO ended:NO];
    [state updateEventId:@"B"];
    NSCAssert(![state observeUUID:@"incoming-A" outgoing:NO ended:YES], @"Old claimed call end cannot clear new event");
    [state observeUUID:@"incoming-B" outgoing:NO ended:NO];
    NSCAssert([[state observeUUID:@"incoming-B" outgoing:NO ended:YES] isEqual:@"B"], @"Matched current call returns captured event");
    NSCAssert(![state observeUUID:@"incoming-B" outgoing:NO ended:YES], @"Duplicate end ignored");
    [state observeUUID:@"already-ringing" outgoing:NO ended:NO];
    [state updateEventId:@"C"];
    [state updateEventId:@"C"];
    NSCAssert([[state observeUUID:@"already-ringing" outgoing:NO ended:YES] isEqual:@"C"], @"Unique ringing call before payload can associate");
    [state observeUUID:@"first" outgoing:NO ended:NO];
    [state observeUUID:@"second" outgoing:NO ended:NO];
    [state updateEventId:@"D"];
    NSCAssert(![state observeUUID:@"first" outgoing:NO ended:YES], @"Ambiguous active calls not guessed");
    NSCAssert(![state observeUUID:@"second" outgoing:NO ended:YES], @"Ambiguous event remains unbound");
    [state updateEventId:@"E"];
    [state observeUUID:@"account-old" outgoing:NO ended:NO];
    [state updateEventId:nil];
    [state updateEventId:@"F"];
    NSCAssert(![state observeUUID:@"account-old" outgoing:NO ended:YES], @"Account reset does not recycle an ongoing old UUID");
    NSLog(@"Incoming call association tests passed");
 }
 return 0;
}
