#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerNativeIntroduction : UIViewController
@property (nonatomic, copy, nullable) dispatch_block_t onStart;
@property (nonatomic, copy, nullable) dispatch_block_t onExit;
@property (nonatomic, copy, nullable) BOOL (^isCurrent)(void);
@end
NS_ASSUME_NONNULL_END
