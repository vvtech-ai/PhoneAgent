//
//  DTFOCRCaptureView.h
//  OCRDetectSDKForTech
//
//  Created by jiangzhipeng on 2025/1/6.
//  Copyright © 2025 Alipay. All rights reserved.
// 拍照页面。提供拍照功能

#import "DTFOCRComponentView.h"

typedef NS_ENUM(NSUInteger, DTFOCRCaptureViewStyle) {
    DTFOCRCaptureViewStylePrepare,//准备拍照
    DTFOCRCaptureViewStyleComfirm,//确认照片
};

NS_ASSUME_NONNULL_BEGIN

@interface DTFOCRCaptureView : DTFOCRComponentView

@property (nonatomic, strong) UILabel *desLabel;//描述文字
@property (nonatomic, strong) UIButton *retryButton;//重试按钮
@property (nonatomic, strong) UIButton *completeButton;//完成按钮
@property (nonatomic, strong) UIButton *takeButton;//拍照按钮
@property (nonatomic, strong) UIButton *closeButton;//关闭按钮
@property (nonatomic, strong) UIButton *flashButton;//闪光灯切换按钮
@property (nonatomic, strong) UIImageView *focusImageView;//取景框图片
@property (nonatomic, copy) void(^closeBlock)();//关闭界面回调
@property (nonatomic, copy) void(^confirmImageBlock)(UIImage *anImage);//确认图片回调
@property(nonatomic, assign) CGRect cropRect;//设置取景框尺寸，相对previewLayer的坐标
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;//预览图层
@property (nonatomic, strong, nullable) UIImageView *previewImageView;//照片预览imageView
@property(nonatomic, strong) CAShapeLayer *fillLayer; //单黑色背景

//获取真实的裁剪尺寸,默认返回cropRect
- (CGRect)realCropRect;
//设置取景框大小
- (void)setFocusRect:(CGRect)rect;
//更新UI
- (void)updateUI:(BOOL)isFront;
//切换当前view的样式
- (void)changeToStyle:(DTFOCRCaptureViewStyle)style;
//更新预览图层，
- (void)updatePreviewLayer:(AVCaptureVideoPreviewLayer *)layer;

//拍照
- (void)takePhoto;
//确认照片
- (void)confirm;
//关闭
- (void)close;
//重拍
- (void)retake;
//切换闪光灯状态
- (void)switchFlashMode;

@end

NS_ASSUME_NONNULL_END
