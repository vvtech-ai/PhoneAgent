#import <Foundation/Foundation.h>
#import "IdentityCaptureSDKInitialization.h"

static NSUInteger assertions;
static void check(BOOL value, NSString *message) {
    assertions++;
    if (!value) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

int main(void) {
    @autoreleasepool {
        __block NSUInteger calls = 0;
        check(calls == 0, @"process startup does not initialize SDK");
        BOOL caught = NO;
        @try {
            [IdentityCaptureSDKInitialization ensureInitialized:^{
                calls++;
                @throw [NSException exceptionWithName:@"SyntheticInitializationFailure" reason:nil userInfo:nil];
            }];
        } @catch (NSException *exception) {
            caught = [exception.name isEqualToString:@"SyntheticInitializationFailure"];
        }
        check(caught && calls == 1, @"initialization exception propagates to existing caller");
        [IdentityCaptureSDKInitialization ensureInitialized:^{
            check(NSThread.isMainThread, @"initialization preserves caller thread");
            calls++;
        }];
        check(calls == 2, @"explicit retry runs after initialization exception");

        // Distinct caller blocks model independent sessions/plugin instances.
        for (NSUInteger session = 0; session < 25; session++) {
            [IdentityCaptureSDKInitialization ensureInitialized:^{ calls++; }];
        }
        check(calls == 2, @"new sessions and callers reuse process initialization");

        // A failure after init (e.g. MetaInfo) must not invalidate initialization.
        @try {
            [IdentityCaptureSDKInitialization ensureInitialized:^{ calls++; }];
            @throw [NSException exceptionWithName:@"SyntheticLaterFailure" reason:nil userInfo:nil];
        } @catch (NSException *exception) {
            check([exception.name isEqualToString:@"SyntheticLaterFailure"], @"later failure remains visible");
        }
        [IdentityCaptureSDKInitialization ensureInitialized:^{ calls++; }];
        check(calls == 2, @"later business failure does not reinitialize SDK");
        printf("Identity SDK initialization: %lu assertions passed; no vendor SDK or audio accessed.\n",
               (unsigned long)assertions);
    }
    return 0;
}
