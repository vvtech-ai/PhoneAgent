#import <Flutter/Flutter.h>
#import <UIKit/UIKit.h>

@interface IdentityCapturePlugin : NSObject <FlutterPlugin>
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
                        host:(UIViewController * _Nullable)host NS_SWIFT_NAME(register(with:host:));
@end
