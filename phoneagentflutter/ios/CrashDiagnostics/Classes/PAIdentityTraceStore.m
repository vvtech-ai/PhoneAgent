#import "PAIdentityTraceStore.h"
#import "PACrashProjection.h"
#import <TargetConditionals.h>

@implementation PAIdentityTraceStore {
    NSURL *_directory;
    NSMutableDictionary *_receipts;
}
- (instancetype)initWithDirectory:(NSURL *)directory {
    if ((self = [super init])) { _directory = directory; _receipts = [NSMutableDictionary new]; }
    return self;
}
- (NSMutableDictionary *)load:(NSURL *)file {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file.path error:nil];
    if (!attributes || [attributes fileSize] > 256 * 1024) return nil;
    NSData *data = [NSData dataWithContentsOfURL:file];
    id row = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
    if (![row isKindOfClass:NSMutableDictionary.class] || ![row[@"events"] isKindOfClass:NSMutableArray.class] ||
        ![row[@"context"] isKindOfClass:NSDictionary.class] || ![PACrashProjection validScope:row[@"scope"]]) return nil;
    for (id event in row[@"events"]) {
        if (![event isKindOfClass:NSDictionary.class] || ![event[@"seq"] isKindOfClass:NSNumber.class] ||
            ![event[@"time"] isKindOfClass:NSNumber.class]) return nil;
    }
    return row;
}
- (BOOL)save:(NSDictionary *)row file:(NSURL *)file {
    NSDictionary *attributes = nil;
    NSDataWritingOptions options = NSDataWritingAtomic;
#if TARGET_OS_IOS
    attributes = @{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication};
    options |= NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication;
#endif
    if (![NSFileManager.defaultManager createDirectoryAtURL:_directory withIntermediateDirectories:YES attributes:attributes error:nil]) return NO;
    if (![_directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil]) return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
    return data && data.length <= 256 * 1024 && [data writeToURL:file options:options error:nil];
}
- (NSArray<NSURL *> *)files {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:_directory
        includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:0 error:nil] ?: @[];
    files = [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL *url, id bindings) {
        return [url.lastPathComponent rangeOfString:@"^[a-f0-9]{64}-[a-f0-9-]{36}\\.json$" options:NSRegularExpressionSearch].location != NSNotFound;
    }]];
    return [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *left = nil, *right = nil;
        [a getResourceValue:&left forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&right forKey:NSURLContentModificationDateKey error:nil];
        return [(left ?: NSDate.distantPast) compare:(right ?: NSDate.distantPast)];
    }];
}
- (void)prune {
    NSArray *files = [self files];
    for (NSUInteger index = 0; index < files.count; index++) {
        NSURL *file = files[index]; NSDate *date = nil;
        [file getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        if (index + 32 < files.count || (date && [date timeIntervalSinceNow] < -7 * 86400)) {
            [NSFileManager.defaultManager removeItemAtURL:file error:nil];
        }
    }
}
- (BOOL)append:(NSDictionary *)event context:(NSDictionary *)context scope:(NSString *)scope {
    if (![PACrashProjection validScope:scope] || ![[NSUUID alloc] initWithUUIDString:context[@"runId"] ?: @""]) return NO;
    NSURL *file = [_directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json", scope, [context[@"runId"] lowercaseString]]];
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:file.path];
    NSMutableDictionary *row = exists ? [self load:file] : [@{@"scope":scope, @"events":[NSMutableArray new], @"discarded":@0} mutableCopy];
    if (!row) return NO; // Preserve unreadable evidence; do not overwrite it.
    NSMutableArray *events = row[@"events"];
    [events addObject:event];
    NSUInteger removed = events.count > 128 ? events.count - 128 : 0;
    if (removed) [events removeObjectsInRange:NSMakeRange(0, removed)];
    row[@"discarded"] = @([row[@"discarded"] unsignedIntegerValue] + removed);
    NSMutableDictionary *metadata = [context mutableCopy];
    metadata[@"dropped"] = @([context[@"dropped"] unsignedIntegerValue] + [row[@"discarded"] unsignedIntegerValue]);
    row[@"context"] = metadata;
    BOOL saved = [self save:row file:file];
    if (saved) [self prune];
    return saved;
}
- (NSArray<NSDictionary *> *)read:(NSString *)scope {
    if (![PACrashProjection validScope:scope]) return @[];
    [self prune]; NSMutableArray *result = [NSMutableArray new];
    // Prioritize the incident's recent runs when old imports have accumulated.
    for (NSURL *file in [[self files] reverseObjectEnumerator]) {
        if (![file.lastPathComponent hasPrefix:[scope stringByAppendingString:@"-"]]) continue;
        NSMutableDictionary *stored = [self load:file];
        if (!stored) return nil;
        NSArray *events = stored[@"events"];
        if (events.count == 0) continue;
        NSMutableDictionary *details = [stored[@"context"] mutableCopy]; details[@"events"] = events;
        // Stable per exact snapshot, even if a previous import was interrupted.
        NSData *data = [NSJSONSerialization dataWithJSONObject:details options:NSJSONWritingSortedKeys error:nil];
        if (!data) return nil;
        NSString *identity = [PACrashProjection identity:data];
        if (_receipts.count >= 64 && !_receipts[identity]) [_receipts removeObjectForKey:_receipts.allKeys.firstObject];
        _receipts[identity] = @{@"scope":scope, @"file":file, @"sequence":events.lastObject[@"seq"]};
        [result addObject:@{@"id":identity, @"scope":scope, @"platform":@"ios", @"kind":@"identityTrace",
            @"mainThread":@NO, @"time":events.lastObject[@"time"], @"iosTrace":details}];
        if (result.count == 28) break; // Leave four slots for crash reports.
    }
    return result;
}
- (BOOL)acknowledge:(NSString *)scope ids:(NSArray<NSString *> *)ids {
    for (NSString *identity in ids) {
        NSDictionary *receipt = _receipts[identity];
        if (![receipt[@"scope"] isEqual:scope]) continue;
        NSURL *file = receipt[@"file"];
        NSMutableDictionary *row = [self load:file];
        if (!row) return NO;
        NSMutableArray *events = row[@"events"];
        NSIndexSet *committed = [events indexesOfObjectsPassingTest:^BOOL(NSDictionary *event, NSUInteger idx, BOOL *stop) {
            return [event[@"seq"] unsignedLongLongValue] <= [receipt[@"sequence"] unsignedLongLongValue];
        }];
        [events removeObjectsAtIndexes:committed];
        if (![self save:row file:file]) return NO;
        [_receipts removeObjectForKey:identity];
    }
    return YES;
}
@end
