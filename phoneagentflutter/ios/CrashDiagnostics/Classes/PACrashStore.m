#import "PACrashStore.h"
#import <TargetConditionals.h>

@implementation PACrashStore {
    NSURL *_directory;
    NSURL *_file;
}
- (instancetype)initWithDirectory:(NSURL *)directory {
    if ((self = [super init])) {
        _directory = directory;
        _file = [directory URLByAppendingPathComponent:@"pending.json"];
    }
    return self;
}
- (NSMutableDictionary *)load:(NSError **)error {
    if (![[NSFileManager defaultManager] fileExistsAtPath:_file.path])
        return [@{@"rows":[NSMutableArray new], @"seen":[NSMutableArray new]} mutableCopy];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_file.path error:error];
    if (!attributes || [attributes fileSize] > 8 * 1024 * 1024) return nil;
    NSData *data = [NSData dataWithContentsOfURL:_file options:0 error:error];
    if (!data) return nil;
    id state = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error];
    if (![state isKindOfClass:NSMutableDictionary.class] ||
        ![state[@"rows"] isKindOfClass:NSMutableArray.class] ||
        ![state[@"seen"] isKindOfClass:NSMutableArray.class]) return nil;
    for (id row in state[@"rows"]) {
        if (![row isKindOfClass:NSDictionary.class] ||
            ![row[@"id"] isKindOfClass:NSString.class] ||
            ![row[@"scope"] isKindOfClass:NSString.class] ||
            ![row[@"time"] isKindOfClass:NSNumber.class]) return nil;
    }
    for (id identity in state[@"seen"]) {
        if (![identity isKindOfClass:NSString.class]) return nil;
    }
    return state;
}
- (BOOL)save:(NSDictionary *)state error:(NSError **)error {
    NSDictionary *attributes = nil;
#if TARGET_OS_IOS
    attributes = @{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication};
#endif
    if (![[NSFileManager defaultManager] createDirectoryAtURL:_directory
        withIntermediateDirectories:YES attributes:attributes error:error]) return NO;
    if (![_directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:error]) return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:error];
    if (!data || data.length > 8 * 1024 * 1024) return NO;
    NSDataWritingOptions options = NSDataWritingAtomic;
#if TARGET_OS_IOS
    options |= NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication;
#endif
    return [data writeToURL:_file options:options error:error];
}
- (void)prune:(NSMutableDictionary *)state {
    long long cutoff = (long long)((NSDate.date.timeIntervalSince1970 - 7 * 86400) * 1000);
    NSMutableArray *rows = state[@"rows"];
    NSIndexSet *expired = [rows indexesOfObjectsPassingTest:^BOOL(id row, NSUInteger index, BOOL *stop) {
        return ![row isKindOfClass:NSDictionary.class] || [row[@"time"] longLongValue] < cutoff;
    }];
    [rows removeObjectsAtIndexes:expired];
    while (rows.count > 32) [rows removeObjectAtIndex:0];
    NSMutableArray *seen = state[@"seen"];
    while (seen.count > 128) [seen removeObjectAtIndex:0];
}
- (BOOL)append:(NSDictionary *)row error:(NSError **)error {
    NSMutableDictionary *state = [self load:error];
    if (!state) return NO;
    if (![state[@"seen"] containsObject:row[@"id"]]) {
        [state[@"rows"] addObject:row];
        [state[@"seen"] addObject:row[@"id"]];
    }
    [self prune:state];
    return [self save:state error:error];
}
- (NSArray<NSDictionary *> *)read:(NSString *)scope error:(NSError **)error {
    NSMutableDictionary *state = [self load:error];
    if (!state) return nil;
    [self prune:state];
    if (![self save:state error:error]) return nil;
    return [state[@"rows"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, id bindings) {
        return [row[@"scope"] isEqual:scope];
    }]];
}
- (BOOL)acknowledge:(NSString *)scope ids:(NSArray<NSString *> *)ids error:(NSError **)error {
    NSMutableDictionary *state = [self load:error];
    if (!state) return NO;
    NSMutableArray *rows = state[@"rows"];
    NSIndexSet *matches = [rows indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger index, BOOL *stop) {
        return [row[@"scope"] isEqual:scope] && [ids containsObject:row[@"id"]];
    }];
    [rows removeObjectsAtIndexes:matches];
    [self prune:state];
    return [self save:state error:error];
}
@end
