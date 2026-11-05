//
//  DTFOCRComponentView.h
//  OCRDetectSDKForTech
//
//  Created by jiangzhipeng on 2025/1/6.
//  Copyright © 2025 Alipay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <BioAuthEngine/DTFOCRViewProtocol.h>
#import <DTFUtility/DTFLanguageCustomConfig.h>

@class DTFOCRComponentView;

NS_ASSUME_NONNULL_BEGIN

@interface DTFOCRComponentView : UIView
//代理操作对象
@property (nonatomic, weak) id <DTFOCRViewDelegate> delegate;
//初始化UI
- (void)prepareUI;
//获取docConfig对象
- (DTFLanguageCustomDocConfig *)docConfig;

@end

NS_ASSUME_NONNULL_END
