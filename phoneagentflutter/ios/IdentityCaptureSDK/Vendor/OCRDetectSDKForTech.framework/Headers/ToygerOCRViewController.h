//
//  ToygerOCRViewController.h
//  OCRDetectSDKForTech
//
//  Created by jiangzhipeng on 2025/1/3.
//  Copyright © 2025 Alipay. All rights reserved.
// OCR UI自定义容器

#import <UIKit/UIKit.h>
#import <BioAuthEngine/DTFOCRViewProtocol.h>
#import <BioAuthEngine/DTFUICustom.h>

NS_ASSUME_NONNULL_BEGIN

@class ZimRpcManager;
@interface ToygerOCRViewController : UIViewController

@property (nonatomic, strong) id<DTFOCRViewProtocol> ocrView;
@property (nonatomic, copy) NSString *certifyId;
@property (nonatomic, strong) ZimRpcManager * rpcManager;
@property (nonatomic, copy) void(^OCRDetectBlock)(BOOL success,NSObject *result);//回调
@property (nonatomic, assign) BOOL isClose;


@end

NS_ASSUME_NONNULL_END
