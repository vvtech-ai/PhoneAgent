//
//  DTFBaseModelDownloader.h
//  DTFUtility
//
//  通用模型下载基类，封装 needDownload / modelPath / startDownload /
//  多备用 URL 兜底链 / forceDownload / 本地校验 等公共流程。
//  子类通过覆写下方钩子方法定制具体模型（face/mouth 等）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFBaseModelDownloader : NSObject

@property(nonatomic, assign) BOOL preload;
@property(nonatomic, copy, nullable) NSString *hostModelURL;

- (void)setModelDownloadURL:(NSArray *)array;
- (nullable NSString *)modelPath;
- (BOOL)needDownload;
- (void)processForceDownload:(NSString *)downloadId;
- (void)startDownloadCompletion:(void (^)(BOOL success))completion;

#pragma mark - Subclass Hooks (必须覆写)

/// 期望的模型文件 MD5
+ (NSString *)expectedMD5;

/// 默认 URL 列表（按优先级），首选 OSS、备用 CDN
+ (NSArray<NSString *> *)defaultURLs;

/// 本地保存的模型文件名，如 toyger.face.dat / toyger.mouth.dat
+ (NSString *)targetFileName;

/// SDK 内置 bundle 名，如 ToygerService.bundle
+ (NSString *)builtInBundleName;

/// 埋点 seed id
+ (NSString *)logSeedId;

/// 网络超时（秒），默认 10
+ (NSTimeInterval)downloadTimeout;

/// 录最后一次成功下载所用的 URL
+ (NSString *)downloadURLUserDefaultsKey;

/// 存储"待执行"的强制下载任务 ID
+ (NSString *)forceDownloadIdUserDefaultsKey;

/// 存储"已完成"的强制下载任务 ID。
+ (NSString *)forceDownloadedIdUserDefaultsKey;

#pragma mark - 子类可访问的工具方法

+ (BOOL)modelExistAndValid;
+ (BOOL)isModelBuiltIn;
+ (NSString *)builtInModelPath;
+ (NSURL *)modelLocation;
+ (BOOL)needForceDownload;

@end

NS_ASSUME_NONNULL_END
