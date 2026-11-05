#import <UIKit/UIKit.h>
#import <Flutter/Flutter.h>
@interface RecordingProbeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation RecordingProbeDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    FlutterDartProject *project = [[FlutterDartProject alloc] initWithPrecompiledDartBundle:NSBundle.mainBundle];
    FlutterViewController *controller = [[FlutterViewController alloc] initWithProject:project nibName:nil bundle:nil];
    Class<FlutterPlugin> encoder = NSClassFromString(@"PhoneAgentRecordingProbe.DomesticRecordingChannel");
    NSAssert(encoder != Nil, @"Actual recording encoder must be linked");
    [encoder registerWithRegistrar:[controller registrarForPlugin:@"PhoneAgentDomesticRecording"]];
    Class<FlutterPlugin> inspector = NSClassFromString(@"PhoneAgentRecordingProbeInspector");
    NSAssert(inspector != Nil, @"Synthetic inspector must be linked");
    [inspector registerWithRegistrar:[controller registrarForPlugin:@"PhoneAgentRecordingProbeInspector"]];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(RecordingProbeDelegate.class)); }
}
