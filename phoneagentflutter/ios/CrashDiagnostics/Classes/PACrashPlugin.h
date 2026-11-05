#import <Flutter/Flutter.h>
@interface PACrashPlugin : NSObject <FlutterPlugin>
/// Initialize once, before normal plugin/SDK startup. Never triggers a crash.
+ (void)start;
@end
