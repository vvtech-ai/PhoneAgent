#import <Foundation/Foundation.h>
@class PLCrashReport;
@interface PACrashProjection : NSObject
+ (BOOL)validScope:(id)value;
+ (NSString *)safeToken:(id)value;
+ (NSString *)identity:(NSData *)data;
+ (NSDictionary *)project:(PLCrashReport *)report data:(NSData *)data;
@end
