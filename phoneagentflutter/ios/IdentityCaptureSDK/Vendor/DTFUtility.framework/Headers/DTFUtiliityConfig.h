//
//  DTFUtiliityConfig.h
//  DTFUtility
//
//  Created by 汪澌哲 on 2023/1/29.
//  Copyright © 2023 com.DTF.iphoneclient.zoloz. All rights reserved.
//

#ifndef DTFUtiliityConfig_h
#define DTFUtiliityConfig_h


#endif /* DTFUtiliityConfig_h */
//reflection
static NSString *const kDTWifiUtilsClassName = @"DTWifiUtils";
static NSString *const kDTFRemoteLoggerClassName = @"DTFRemoteLogger";
static NSString *const kASSSgomInfoOpenClassName = @"ASSSgomInfoOpen";

static NSString *const kAPDIDClassName = @"APDID";
static NSString *const kASSSecureOpenSdkClassName = @"ASSSecureOpenSdk";
static NSString *const kGetTokenResultSelectorName = @"getTokenResult:appKeyClient:";
static NSString *const kUpdateTokenSelectorName = @"updateToken:appKeyClient:parameters:callback:";
static NSString *const kInitTokenSelectorName = @"initToken:appKeyClient:parameters:callback:";
static NSString *const kInitTokenCallbackSelectorName = @"initToken:appKeyClient:callback:";
static NSString *const kUpdateSgomInfoSelectorName = @"updateSgomInfo:ext:";

static NSString *const kAPSecureSdkClassName = @"APSecureSdk";
static NSString *const kInitWithParamsSelectorName = @"initWithParams:bizToken:appName:";
static NSString *const kSharedInstanceSelectorName = @"sharedInstance";
static NSString *const kInitWithRpcConfigurationSelectorName = @"initWithRpcConfiguration:";
static NSString *const kIsSupportFaceShieldSelectorName = @"isSupportFaceShield";
static NSString *const kIsTrackingAuthorizationSelectorName = @"isTrackingAuthorization";

//userDefaults key
static NSString *const kDTFUtilityLanguageUserDefaultsKey = @"kAPLanguageSettingKey";
static NSString *const kDTFUtilitySystemLangNameUserDefaultsKey = @"AppleLanguages";
static NSString *const kDTFAliyunPrivateDemoHostUserDefaultsKey = @"Aliyun_privateDemo_host";

//logServer
static NSString *const kDTFUtilityLogServerURL = @"https://mdap.mpaas.cn-hangzhou.aliyuncs.com/loggw/logUpload.do";
static NSString *const kDTFUtilityLogPlatformID = @"8FA6890301632_IOS-prod";

static NSString *const kDTFZimModelDownloaderOssUrl = @"https://cn-shanghai-aliyun-cloudauth.oss-cn-shanghai.aliyuncs.com/model/toyger.face.ios.dat";
static NSString *const kDTFModelDir = @"ToygerModel";
static NSString *const kDTFTargetURL = @"toyger.face.dat";

static NSString *const kDTFDocMultiPath = @"dtf/lang/doc";
static NSString *const kDTFFaceMultiPath = @"dtf/lang/face";
static NSString *const kZANDocMultiPath = @"dtf/lang/zan/doc";
static NSString *const kZANFaceMultiPath = @"dtf/lang/zan/face";
static NSString *const kDTFErrorMessage = @"errMsg";
static NSString *const kDTFBeautyLayer= @"DTFBeautyLayer"; // 美颜
static NSString *const kDisplayframePixelBuffer = @"displayframePixelBuffer:";
