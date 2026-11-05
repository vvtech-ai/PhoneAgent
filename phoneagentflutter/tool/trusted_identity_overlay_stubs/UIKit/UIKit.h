// Test double for coordinator unit tests on macOS; not a UIKit rendering test.
#import <Foundation/Foundation.h>
extern NSString *const UIApplicationDidBecomeActiveNotification;
typedef NS_ENUM(NSInteger, UIApplicationState) { UIApplicationStateActive, UIApplicationStateInactive, UIApplicationStateBackground };
typedef NS_ENUM(NSInteger, UIModalPresentationStyle) { UIModalPresentationFullScreen };
@interface UIView : NSObject
@property (nonatomic, strong) id window;
@end
@interface UIApplication : NSObject
@property (nonatomic) UIApplicationState applicationState;
+ (instancetype)sharedApplication;
@end
@protocol UIViewControllerTransitionCoordinatorContext <NSObject>
@end
@protocol UIViewControllerTransitionCoordinator <NSObject>
- (BOOL)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))animation
    completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))completion;
@end
@interface UIViewController : NSObject
@property (nonatomic, strong) UIView *viewIfLoaded;
@property (nonatomic, strong) UIViewController *presentedViewController;
@property (nonatomic, weak) UIViewController *presentingViewController;
@property (nonatomic, strong) id<UIViewControllerTransitionCoordinator> transitionCoordinator;
@property (nonatomic) BOOL isBeingPresented, isBeingDismissed, modalInPresentation;
@property (nonatomic) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic) NSUInteger presentations, dismissals;
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
@end
