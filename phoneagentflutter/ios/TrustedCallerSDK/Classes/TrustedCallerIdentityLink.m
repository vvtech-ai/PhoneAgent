#import "TrustedCallerIdentityLink.h"
NSString *TrustedCallerEventIdFromURL(NSURL *url) {
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (![parts.scheme.lowercaseString isEqual:@"aiassistanttrustedcall"] ||
        ![parts.host.lowercaseString isEqual:@"identity"] || parts.path.length ||
        parts.user || parts.password || parts.port || parts.fragment || parts.queryItems.count != 1) return nil;
    NSURLQueryItem *item = parts.queryItems.firstObject;
    if (![item.name isEqual:@"eventId"] || item.value.length != 36 || ![[NSUUID alloc] initWithUUIDString:item.value]) return nil;
    return item.value.copy;
}
