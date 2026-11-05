//
//  ChakenSdk.h
//  KXSSDK
//
//  Created by user on 2022/5/23.
//  Copyright © 2022 nat. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


typedef void(^KXChakenSdkBlock)(NSInteger code ,NSDictionary * _Nonnull data);

@interface ChakenSdk : NSObject


/**
 * @brief 单例
 */
+ (instancetype)sharedInstance;

/// 禁用掉 alloc、new 、copy等方法，
/// 强制使用 sharedInstance 方法来创建对象
- (instancetype) init __attribute__((unavailable("replace with 'sharedInstance'")));
+ (instancetype) alloc __attribute__((unavailable("replace with 'sharedInstance'")));
+ (instancetype) new __attribute__((unavailable("replace with 'sharedInstance'")));
- (instancetype) copy __attribute__((unavailable("replace with 'sharedInstance'")));
- (instancetype) mutableCopy __attribute__((unavailable("replace with 'sharedInstance'")));


#pragma mark 初始化配置Appkey和授权码
/// @param appkey Appkey
/// @param appSecret 授权码 
- (void)setAppKey:(NSString *)appkey AppSecret:(NSString *)appSecret callback:(KXChakenSdkBlock _Nullable)callback;

#pragma mark  手机号与推送通道绑定
/// @param phone 登陆的手机号
/// @param jiguangRid 极光的返回的registrationID
- (void)bindRid:(NSString *)phone JiguangRid:(NSString *)jiguangRid callback:(KXChakenSdkBlock _Nullable)callback;

/// 同时绑定极光 RID 和 APNS device token，后端根据配置的优先级选择推送通道。
/// @param phone 登录的手机号
/// @param jiguangRid 极光 registrationID；未接入极光时传空字符串
/// @param deviceToken 苹果 APNS device token（64 位十六进制字符串）
- (void)bindRid:(NSString *)phone
     JiguangRid:(NSString *)jiguangRid
    deviceToken:(NSString *)deviceToken
       callback:(KXChakenSdkBlock _Nullable)callback;

#pragma mark  sdk授权上报接口
- (void)sdkAuthLogCallback:(KXChakenSdkBlock _Nullable)callback;

#pragma mark 解析通信令牌token
/// @param tokenString 通信令牌token
/// @param callerPhone 主叫手机号
/// @param calledPhoneStr 被叫手机号
/// @param sequence 身份序列号
- (void)parseIdentityToken:(NSString *)tokenString callerPhone:(NSString *)callerPhone calledPhoneStr:(NSString *)calledPhoneStr  sequence:(NSString *)sequence callback:(KXChakenSdkBlock _Nullable)callback;










@end

NS_ASSUME_NONNULL_END
