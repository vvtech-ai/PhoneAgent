//
//  DTFOCRVerifyResultModel.h
//  OCRDetectSDKForTech
//
//  Created by jiangzhipeng on 2025/2/12.
//  Copyright © 2025 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface DTFOCRVerifyResultDetailModel : NSObject

@property (nonatomic, copy) NSString *CertName;//姓名
@property (nonatomic, copy) NSString *CertNo;//身份证号
@property (nonatomic, copy) NSString *NowDate;//当前日期
@property (nonatomic, copy) NSString *EndDate;//身份证有效截止日志
@property (nonatomic, copy) NSString *StartDate;//身份证有效开始日期

/// 裁剪区域 高度
@property (nonatomic, assign) CGFloat cardHeight;

/// 裁剪区域 左边距离
@property (nonatomic, assign) CGFloat cardLeft;

/// 裁剪区域 顶部距离
@property (nonatomic, assign) CGFloat cardTop;

/// 裁剪区域 宽度
@property (nonatomic, assign) CGFloat cardWidth;

/// 是否有裁剪区域信息
- (BOOL)isHaveCardCropInfo;

@end

@interface DTFOCRVerifyResultModel : NSObject

@property (nonatomic, copy) NSString *RetCode;//信息码
@property (nonatomic, copy) NSString *RetCodeSub;//信息z码
@property (nonatomic, copy) NSString *RetMessageSub;//信息返回值
@property (nonatomic, strong) DTFOCRVerifyResultDetailModel *OcrInfo;//ocr识别信息

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
