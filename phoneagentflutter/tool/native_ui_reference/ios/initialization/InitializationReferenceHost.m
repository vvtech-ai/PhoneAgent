#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "GeneratedInitializationPresentation.h"

// Local synthetic navigation only. Original service/controller actions are absent.
@interface InitializationReferenceHost : InitializationPresentationReference
@property(nonatomic, copy) NSString *selectedProvider;
@property(nonatomic, strong) NSArray<AIInitializationProviderOption *> *options;
@property(nonatomic) BOOL finished;
@end

@implementation InitializationReferenceHost
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    self.identityName = @"";
    self.identityPhone = @"";
    self.identityGender = @"不透露";
    self.errorMessage = @"";
    self.selectedProvider = @"QWEN_OMNI_PLUS";
    NSMutableArray *options = [NSMutableArray new];
    NSArray *ids = @[@"QWEN_OMNI_PLUS", @"DOUBAO", @"DOUBAO_SEEDUPLEX_3_0"];
    NSArray *titles = @[@"QwenOmniPlus", @"Seeduplex", @"Seeduplex V3"];
    NSArray *details = @[@"测试模型一", @"测试模型二", @"合成克隆模型"];
    NSArray *capabilities = @[@"支持系统音色和声音克隆", @"仅支持系统音色", @""];
    for (NSUInteger index = 0; index < ids.count; index++) {
        AIInitializationProviderOption *option = [AIInitializationProviderOption new];
        option.providerId = ids[index]; option.title = titles[index];
        option.subtitle = details[index]; option.capability = capabilities[index];
        option.enabled = YES; option.recommended = index == 0;
        [options addObject:option];
    }
    self.options = options;
    self.step = 1;
    [self buildLayout];
    [self rebuildPresentation];
}
- (BOOL)current {
    return !self.finished && self.isViewLoaded && self.view.window != nil;
}
- (void)updateLocalAction {
    [self.actionButton setTitle:self.step == 1 ? @"下一步" : @"完成"
                     forState:UIControlStateNormal];
    self.actionButton.enabled = self.step == 2 ||
        [self.identityName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
}
- (void)rebuildPresentation {
    [self.view endEditing:YES];
    for (UIView *view in self.stepStack.arrangedSubviews.copy) {
        [self.stepStack removeArrangedSubview:view]; [view removeFromSuperview];
    }
    self.backButton.hidden = self.step == 1;
    self.skipButton.hidden = self.step != 1;
    if (self.step == 1) [self buildIdentityStep];
    else [self buildProviderStepWithTitle:@"通话语音模型"
        subtitle:@"选择AI 外呼通话模型" options:self.options selected:self.selectedProvider];
    [self updateLocalAction];
}
- (void)nameChanged:(UITextField *)field {
    if (![self current]) return;
    self.identityName = field.text ?: @""; [self updateLocalAction];
}
- (void)phoneChanged:(UITextField *)field {
    if (![self current]) return;
    self.identityPhone = field.text ?: @"";
}
- (void)genderTapped:(UIButton *)sender {
    if (![self current] || self.step != 1) return;
    self.identityGender = @[@"不透露", @"男", @"女"][sender.tag];
    [self rebuildPresentation];
}
- (void)providerCardTapped:(UIControl *)sender {
    if (![self current] || self.step != 2) return;
    self.selectedProvider = objc_getAssociatedObject(sender, @selector(providerCardTapped:));
    [self rebuildPresentation];
}
- (void)backTapped {
    if (![self current] || self.step != 2) return;
    self.step = 1; [self rebuildPresentation];
}
- (void)skipIdentityTapped {
    if (![self current] || self.step != 1) return;
    self.step = 2; [self rebuildPresentation];
}
- (void)actionTapped {
    if (![self current] || !self.actionButton.enabled) return;
    if (self.step == 1) { self.step = 2; [self rebuildPresentation]; return; }
    self.finished = YES;
    UIViewController *returned = [UIViewController new];
    returned.view.backgroundColor = UIColor.whiteColor;
    UILabel *label = [UILabel new];
    label.text = [@"合成初始化已返回：" stringByAppendingString:self.selectedProvider];
    label.textAlignment = NSTextAlignmentCenter; label.numberOfLines = 0;
    [returned.view addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(returned.view); make.leading.trailing.equalTo(returned.view).inset(20);
    }];
    self.view.window.rootViewController = returned;
}
@end

@interface ReferenceDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ReferenceDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [InitializationReferenceHost new];
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ReferenceDelegate.class)); }
}
