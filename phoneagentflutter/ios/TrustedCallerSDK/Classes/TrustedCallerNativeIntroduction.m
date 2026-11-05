#import "TrustedCallerNativeIntroduction.h"
#import <Masonry/Masonry.h>

// Reference UIKit layout and navigation, with bridge-owned account callbacks.
@interface TrustedCallerNativeIntroduction ()
@property (nonatomic, strong) CAGradientLayer *backgroundGradientLayer;
@property (nonatomic, strong) UIImageView *phoneImageView;
@property (nonatomic, copy) NSArray<UIImage *> *phoneImages;
@property (nonatomic, assign) NSInteger currentImageIndex;
@property (nonatomic, strong, nullable) NSTimer *rotationTimer;
@end

@implementation TrustedCallerNativeIntroduction

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:20.0 / 255.0 green:44.0 / 255.0 blue:190.0 / 255.0 alpha:1.0];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (__bridge id)[UIColor colorWithRed:12.0 / 255.0 green:151.0 / 255.0 blue:251.0 / 255.0 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:18.0 / 255.0 green:39.0 / 255.0 blue:184.0 / 255.0 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:gradient atIndex:0];
    self.backgroundGradientLayer = gradient;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.text = @"可信通信组件";
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightRegular];
    titleLabel.textAlignment = NSTextAlignmentCenter;

    UILabel *badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    badgeLabel.text = @"来电归属地升级版";
    badgeLabel.textColor = [UIColor colorWithRed:14.0 / 255.0 green:132.0 / 255.0 blue:240.0 / 255.0 alpha:1.0];
    badgeLabel.backgroundColor = UIColor.whiteColor;
    badgeLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.layer.cornerRadius = 14.0;
    badgeLabel.layer.masksToBounds = YES;

    UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    descriptionLabel.text = @"基于\"可信通信\"国家标准的被叫服务\n展示带签名来电的数字证书，防篡改，防伪造";
    descriptionLabel.textColor = UIColor.whiteColor;
    descriptionLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    descriptionLabel.textAlignment = NSTextAlignmentCenter;
    descriptionLabel.numberOfLines = 2;

    NSMutableArray<UIImage *> *images = [NSMutableArray arrayWithCapacity:3];
    for (NSInteger index = 1; index <= 3; index++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"sdk_show_icon%ld", (long)index]];
        if (image) {
            [images addObject:image];
        }
    }
    self.phoneImages = images.copy;
    self.currentImageIndex = 0;

    UIImageView *phoneImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    phoneImageView.contentMode = UIViewContentModeScaleAspectFit;
    phoneImageView.clipsToBounds = YES;
    phoneImageView.image = self.phoneImages.firstObject;
    self.phoneImageView = phoneImageView;

    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.backgroundColor = UIColor.whiteColor;
    startButton.layer.cornerRadius = 5.0;
    startButton.layer.masksToBounds = YES;
    [startButton setTitle:@"开始" forState:UIControlStateNormal];
    [startButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    startButton.titleLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightRegular];
    [startButton addTarget:self action:@selector(startTrustedCalleeService) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:titleLabel];
    [self.view addSubview:badgeLabel];
    [self.view addSubview:descriptionLabel];
    [self.view addSubview:phoneImageView];
    [self.view addSubview:startButton];

    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(28.0);
        make.leading.trailing.equalTo(self.view).insets(UIEdgeInsetsMake(0, 20.0, 0, 20.0));
    }];
    [badgeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLabel.mas_bottom).offset(12.0);
        make.centerX.equalTo(self.view);
        make.width.equalTo(self.view).multipliedBy(0.60);
        make.height.mas_equalTo(28.0);
    }];
    [descriptionLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(badgeLabel.mas_bottom).offset(12.0);
        make.leading.trailing.equalTo(self.view).insets(UIEdgeInsetsMake(0, 26.0, 0, 26.0));
    }];
    [phoneImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(descriptionLabel.mas_bottom).offset(18.0);
        make.leading.trailing.equalTo(self.view).insets(UIEdgeInsetsMake(0, 20.0, 0, 20.0));
        make.bottom.equalTo(startButton.mas_top).offset(-20.0);
    }];
    [startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(self.view).insets(UIEdgeInsetsMake(0, 16.0, 0, 16.0));
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-20.0);
        make.height.mas_equalTo(56.0);
    }];

    UIScreenEdgePanGestureRecognizer *dismissGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissGesture:)];
    dismissGesture.edges = UIRectEdgeLeft;
    [self.view addGestureRecognizer:dismissGesture];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.backgroundGradientLayer.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startImageRotation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopImageRotation];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)startImageRotation {
    [self stopImageRotation];
    if (self.phoneImages.count < 2) {
        return;
    }
    self.rotationTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                          target:self
                                                        selector:@selector(showNextPhoneImage)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)stopImageRotation {
    [self.rotationTimer invalidate];
    self.rotationTimer = nil;
}

- (void)showNextPhoneImage {
    if (self.phoneImages.count == 0) {
        return;
    }
    self.currentImageIndex = (self.currentImageIndex + 1) % self.phoneImages.count;
    [UIView transitionWithView:self.phoneImageView
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
        self.phoneImageView.image = self.phoneImages[self.currentImageIndex];
    } completion:nil];
}

- (void)startTrustedCalleeService {
    if (self.isCurrent && !self.isCurrent()) { [self finishAndDismiss]; return; }
    if (self.navigationController.topViewController != self) return;
    [self stopImageRotation];
    if (self.onStart) self.onStart();
}
- (void)finishAndDismiss {
    dispatch_block_t exit = self.onExit;
    self.onExit = nil;
    if (exit) exit();
}

- (void)handleDismissGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded || self.navigationController.viewControllers.firstObject != self) {
        return;
    }
    CGPoint translation = [gesture translationInView:self.view];
    if (translation.x > 60.0) {
        [self finishAndDismiss];
    }
}

@end
