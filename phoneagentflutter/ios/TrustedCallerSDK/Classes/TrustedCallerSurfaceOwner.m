#import "TrustedCallerSurfaceOwner.h"
#import <string.h>

@implementation TrustedCallerSurfaceOwner
+ (NSDictionary *)accountRequestFromArguments:(id)arguments expectedEnvironment:(NSString *)environment {
    if (![arguments isKindOfClass:NSDictionary.class] ||
        ![@[@"test", @"pro"] containsObject:environment]) return nil;
    NSDictionary *fields = arguments;
    id account = fields[@"owner"];
    if (!account || ![fields[@"environment"] isEqual:environment]) return nil;
    if (account == NSNull.null) return @{@"owner": NSNull.null};
    if (![account isKindOfClass:NSDictionary.class] ||
        ![[NSSet setWithArray:[account allKeys]] isEqualToSet:
            [NSSet setWithArray:@[@"accountId", @"phone", @"loginEpoch"]]]) return nil;
    NSMutableDictionary *validation = [account mutableCopy];
    validation[@"environment"] = environment;
    validation[@"surfaceToken"] = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    TrustedCallerSurfaceOwner *owner = [self ownerFromArguments:validation];
    if (!owner) return nil;
    NSMutableDictionary *metadata = owner.metadata.mutableCopy;
    [metadata removeObjectForKey:@"surfaceToken"];
    return @{@"owner": metadata.copy};
}
+ (instancetype)ownerFromArguments:(id)arguments {
    if (![arguments isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *args = arguments;
    NSString *token = args[@"surfaceToken"], *account = args[@"accountId"],
        *phone = args[@"phone"], *environment = args[@"environment"];
    NSNumber *epoch = args[@"loginEpoch"];
    for (id text in @[token ?: NSNull.null, account ?: NSNull.null, phone ?: NSNull.null,
                     environment ?: NSNull.null]) {
        if (![text isKindOfClass:NSString.class] ||
            [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0 ||
            [text rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return nil;
    }
    if ([token rangeOfString:@"^[0-9a-f]{32}$" options:NSRegularExpressionSearch].location == NSNotFound ||
        ![@[@"test", @"pro"] containsObject:environment] ||
        ![epoch isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)epoch) == CFBooleanGetTypeID()) return nil;
    const char *type = epoch.objCType;
    if (strlen(type) != 1 || strchr("cCsSiIlLqQ", type[0]) == NULL || epoch.longLongValue < 0) return nil;
    TrustedCallerSurfaceOwner *owner = [[self alloc] init];
    owner->_metadata = @{@"surfaceToken": token.copy, @"accountId": account.copy,
        @"phone": phone.copy, @"loginEpoch": epoch.copy, @"environment": environment.copy};
    return owner;
}
- (BOOL)matches:(TrustedCallerSurfaceOwner *)other {
    return other && [self.metadata isEqualToDictionary:other.metadata];
}
- (BOOL)matchesAccountMetadata:(NSDictionary *)account {
    if (![account isKindOfClass:NSDictionary.class]) return NO;
    NSMutableDictionary *arguments = account.mutableCopy;
    arguments[@"surfaceToken"] = self.metadata[@"surfaceToken"];
    return [self matches:[TrustedCallerSurfaceOwner ownerFromArguments:arguments]];
}
- (NSDictionary<NSString *, id> *)reportWithFields:(NSDictionary<NSString *, id> *)fields {
    NSMutableDictionary *report = self.metadata.mutableCopy;
    for (NSString *key in @[@"linked", @"configured", @"sdkVersion", @"status",
                           @"explicitSdkAuthorization", @"needsIntroduction"]) {
        if (fields[key]) report[key] = fields[key];
    }
    return report.copy;
}
@end
