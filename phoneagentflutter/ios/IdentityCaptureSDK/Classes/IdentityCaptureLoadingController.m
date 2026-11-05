#import "IdentityCaptureLoadingController.h"

@implementation IdentityCaptureLoadingController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [spinner startAnimating];
    UILabel *title = [UILabel new];
    title.text = @"人脸认证页面加载中";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 0;
    UILabel *detail = [UILabel new];
    detail.text = @"首次加载认证资源可能需要十几秒，请保持网络畅通并耐心等待。\n加载完成后将自动进入人脸跟读认证。";
    detail.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    detail.textColor = UIColor.secondaryLabelColor;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.numberOfLines = 0;
    title.adjustsFontForContentSizeCategory = YES;
    detail.adjustsFontForContentSizeCategory = YES;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[spinner, title, detail]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [title.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [detail.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:32],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-32],
    ]];
}
@end
