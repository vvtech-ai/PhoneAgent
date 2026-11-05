//
//  DTFOCRInfoView.h
//  OCRDetectSDKForTech
//
//  Created by jiangzhipeng on 2025/1/6.
//  Copyright © 2025 Alipay. All rights reserved.
//

#import "DTFOCRComponentView.h"
#import <BioAuthEngine/DTFOCRViewProtocol.h>
#import "DetectImageForOCRButton.h"
#import "DetectImageForOCRScrollView.h"
#import "DTFOCRCaptureView.h"
#import "DTFOCRVerifyErrorHintView.h"
#import "DTFOCRVerifyResultModel.h"

typedef NS_ENUM(NSUInteger, DTFOCRVerify) {
    DTFOCRVerifyFront,//认证身份证正面
    DTFOCRVerifyBack,//认证身份证反面
    DTFOCRVerifyTransition,//认证完成，过渡。准备跳转到人脸
};

typedef NS_ENUM(NSUInteger, DTFOCRVerifyAlertStyle) {
    DTFOCRVerifyAlertStyleOCRFailed,//OCR识别失败
    DTFOCRVerifyAlertStyleExit,//退出
    DTFOCRVerifyAlertStyleInputError,//身份信息输入错误
    DTFOCRVerifyAlertStyleCameraAccess,//相机权限
    DTFOCRVerifyAlertStyleAlbumAccess,//相册权限
};

NS_ASSUME_NONNULL_BEGIN
//标题
@interface DTFOCRInfoTitleView : UIView

@property (nonatomic, strong) UIButton *closeButton;//关闭按钮
@property (nonatomic, copy) void(^closeButtonClickedCallback)();
- (void)prepareUI;//在init方法时执行，创建并添加好子view
- (CGSize)viewSize;//返回view的大小
@end

//progressView
@interface DTFOCRInfoProgressView : UIView

@property(nonatomic, strong) UIView *frontToBackVerifyLine;//正面认证到反面认证连接线条
@property(nonatomic, strong) UIView *backToLivenessVerifyLine; //反面认证到活体认证连接线条
@property(nonatomic, strong) UILabel *frontSerialNumberLabel;//正面认证序列号1
@property(nonatomic, strong) UILabel *backSerialNumberLabel;//反面认证序列号2
@property(nonatomic, strong) UILabel *livenessSerialNumberLabel;//活体认证序列号3
@property(nonatomic, strong) UIImageView *frontVerifyStatusImageView;//红点
@property(nonatomic, strong) UIImageView *backVerifyStatusImageView;//第二步红点
@property(nonatomic, strong) UIImageView *livenessVerifyStatusImageView;//第三步红点
@property(nonatomic, strong) UILabel *frontVerifyTipsLabel;  //进度条下面的字
@property(nonatomic, strong) UILabel *backVerifyTipsLabel;//进度条下面的字
@property(nonatomic, strong) UILabel *livenessVerifyTipsLabel;//进度条下面的字
- (void)prepareUI;//在init方法时执行，创建并添加好子view
- (CGSize)viewSize;//返回view的大小

@end

//scanview
@interface DTFOCRInfoScanView : UIView

@property(nonatomic, strong) UILabel *infoTipsLabel;//描述信息
@property(nonatomic, strong) UIImageView *baseImageView;//拍摄提示图片或拍摄结果图片展示view
@property(nonatomic, strong) UIButton *takeRequestButton;//拍照要求按钮
@property(nonatomic, strong) UILabel *bottomTipsLabel;//详细描述信息，如：“证件人像面”
@property(nonatomic, strong) UIImageView *takeImageView;//点击会触发拍照
@property (nonatomic, copy) void(^requestButtonClickedCallback)();//拍照要求按钮被点击回调
@property (nonatomic, copy) void(^captureButtonClickedCallback)(void(^completeBlock)());//拍照按钮点击回调
- (void)prepareUI;//在init方法时执行，创建并添加好子view
- (CGSize)viewSize;//返回view的大小

@end

//confirmview
@interface DTFOCRInfoConfirmView : UIView

@property(nonatomic, strong) UITextField *idTextField;//id输入框
@property(nonatomic, strong) UITextField *nameTextField;//姓名输入框
@property(nonatomic, strong) UIView *nameView;//姓名容器
@property(nonatomic, strong) UIView *idView;//ID容器
@property(nonatomic, strong) UIView *noticeContainer; //提醒内容容器
@property(nonatomic, strong) UILabel *noticeLabel;//提醒文字
@property(nonatomic, strong) UIImageView *noticeHintImageView;//提醒图标
@property(nonatomic, strong) UILabel *nameLabel;// 名字标签
@property(nonatomic, strong) UILabel *idLabel;//ID标签
- (void)prepareUI;//在init方法时执行，创建并添加好子view
- (CGSize)viewSize;//返回view的大小

@end


@interface DTFOCRInfoView : DTFOCRComponentView <DTFOCRViewProtocol>
//titleView
@property(nonatomic, strong) DTFOCRInfoTitleView *titleContentView;
//progressView
@property(nonatomic, strong) DTFOCRInfoProgressView *progressContentView;
//scanview
@property(nonatomic, strong) DTFOCRInfoScanView *scanContentView;;
//confirmview
@property(nonatomic, strong) DTFOCRInfoConfirmView *confirmView;
//下一步按钮
@property(nonatomic, strong) DetectImageForOCRButton *nextButton;
//下一步按钮容器
@property(nonatomic, strong) UIView *nextButtonView;
//滚动视图，scanview和confirmview的容器
@property(nonatomic, strong) UIScrollView *contentScrollView;
//拍照View
@property (nonatomic, strong) DTFOCRCaptureView *captureView;
/// 错误提示view
@property (nonatomic, strong) DTFOCRVerifyErrorHintView *tipsErrorView;
//当前认证进度
@property (nonatomic, assign) DTFOCRVerify currentVerify;

//切换到下一个子进度,DTFOCRVerifyFront-DTFOCRVerifyBack-DTFOCRVerifyTransition调整UI
- (void)updateUIWhenEnterNextVerify;
//更新信息,ocr认证结果
- (void)updateVerifyInfo:(DTFOCRVerifyResultDetailModel *)verifyInfo captureImage:(UIImage *)anImage;
//开始loading动画
- (void)showLoading;
//停止loading动画
- (void)hideLoading;
//显示拍照页面
- (void)showCaptureView:(void (^ __nullable)(void))animateCompletion;
- (void)dismissCaptureView:(void (^ __nullable)(void))animateCompletion;
//显示拍照提示
- (void)showCaptureTips;
//显示图片OCR认证失败提示（图片不符合规范导致）
- (void)showVerifyErrorHint;
//身份证正面信息确认有问题时弹窗，如身份证姓名号码不合规范
- (void)showFrontVerifyInfoErrorToast:(NSString *)errorMsg;
//显示alert提示
- (void)showAlertWithTitle:(NSString *)title message:(nullable NSString *)message alertStyle:(DTFOCRVerifyAlertStyle)style;
//关闭按钮事件
- (void)close;
//下一步按钮事件，如正面验证完成进反面验证
- (NSError *)next;

@end

NS_ASSUME_NONNULL_END

