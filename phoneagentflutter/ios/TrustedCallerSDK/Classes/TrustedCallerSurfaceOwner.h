#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerSurfaceOwner : NSObject
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *metadata;
+ (nullable instancetype)ownerFromArguments:(nullable id)arguments;
+ (nullable NSDictionary *)accountRequestFromArguments:(nullable id)arguments
    expectedEnvironment:(NSString *)environment;
- (BOOL)matches:(nullable TrustedCallerSurfaceOwner *)other;
- (BOOL)matchesAccountMetadata:(nullable NSDictionary *)account;
- (NSDictionary<NSString *, id> *)reportWithFields:(NSDictionary<NSString *, id> *)fields;
@end
NS_ASSUME_NONNULL_END
