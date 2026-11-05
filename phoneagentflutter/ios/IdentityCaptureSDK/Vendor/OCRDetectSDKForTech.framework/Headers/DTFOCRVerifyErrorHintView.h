//
//  DTFOCRVerifyErrorHintView.h
//  OCRDetectSDKForTech
//
//  Created by jiangzhipeng on 2025/1/6.
//  Copyright © 2025 Alipay. All rights reserved.
//

#import "DTFOCRComponentView.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, DTFOCRVerifyErrorHintViewStyle) {
    DTFOCRVerifyErrorHintViewStyleTips,//仅拍照提示
    DTFOCRVerifyErrorHintViewStyleError,//拍照提示 + 跳转拍照
};

@interface DTFOCRVerifyErrorHintView : DTFOCRComponentView

@property (nonatomic, strong) UIView *containerView;//展示内容view
//头部
@property (nonatomic, strong) UILabel *titleLabel;//标题label
@property (nonatomic, strong) UIButton *closeButton;//关闭按钮
@property (nonatomic, strong) UILabel *errorLabel;//错误文本
@property (nonatomic, strong) UILabel *hintLabel;//错误提示文本
@property (nonatomic, strong) UIView *footerDividingLine;//分割线
@property (nonatomic, strong) UIButton *retakeButton;//重拍按钮

@property (nonatomic, strong) UIImageView *baseImageView;//底图
//事件回调
@property (nonatomic, copy) void (^closeActionBlock)();
@property (nonatomic, copy) void (^retakeActionBlock)();

//更新UI样式
- (void)updateContent:(DTFOCRVerifyErrorHintViewStyle)style;
- (void)updateContent:(DTFOCRVerifyErrorHintViewStyle)state title:(NSString *)title;

//关闭界面
- (void)close;
//重拍
- (void)retake;

@end

NS_ASSUME_NONNULL_END
