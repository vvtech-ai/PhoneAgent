//
//  AliyunFaceAuthFacade+MultiFactor.h
//  MultiFactorFacade
//
//  Mouth model preload entry point exposed on AliyunFaceAuthFacade.
//

#import <Foundation/Foundation.h>
#import <AliyunFaceAuthFacade/AliyunFaceAuthFacade.h>

NS_ASSUME_NONNULL_BEGIN

@interface AliyunFaceAuthFacade (MultiFactor)

/// 预下载意愿认证嘴部模型文件。
/// param 中通过 ZIM_EXT_PARAMS_KEY_PRELOAD_MOUTH_MODEL_URL 指定模型地址。
+ (void)multi_preload:(NSDictionary *)param completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
