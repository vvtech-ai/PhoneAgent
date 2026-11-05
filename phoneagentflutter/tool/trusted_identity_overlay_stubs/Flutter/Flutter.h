#import <UIKit/UIKit.h>
typedef void (^FlutterResult)(id);
static NSString *const FlutterMethodNotImplemented = @"notImplemented";
@protocol FlutterBinaryMessenger <NSObject>
@end
@interface FlutterMethodCall : NSObject
@property (nonatomic, copy) NSString *method;
@property (nonatomic, strong) id arguments;
@end
@interface FlutterMethodChannel : NSObject
@property (nonatomic, copy) void (^handler)(FlutterMethodCall *, FlutterResult);
@property (nonatomic, strong) NSMutableArray *sent;
+ (instancetype)methodChannelWithName:(NSString *)name binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (void)setMethodCallHandler:(void (^)(FlutterMethodCall *, FlutterResult))handler;
- (void)invokeMethod:(NSString *)method arguments:(id)arguments;
@end
@interface FlutterEngine : NSObject <FlutterBinaryMessenger>
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, readonly) NSObject<FlutterBinaryMessenger> *binaryMessenger;
@property (nonatomic) BOOL destroyed;
@property (nonatomic, copy) NSString *entrypoint;
- (instancetype)initWithName:(NSString *)name project:(id)project allowHeadlessExecution:(BOOL)allow;
- (BOOL)runWithEntrypoint:(NSString *)entrypoint;
- (void)destroyContext;
@end
@interface FlutterViewController : UIViewController
@property (nonatomic, copy) void (^firstFrame)(void);
- (void)setFlutterViewDidRenderCallback:(void (^)(void))callback;
- (instancetype)initWithEngine:(FlutterEngine *)engine nibName:(NSString *)nib bundle:(id)bundle;
@end
