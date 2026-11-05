#import "TrustedCallerAvatarLoader.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
@interface TrustedCallerAvatarLoader () <NSURLSessionDataDelegate>
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSMutableData *bytes;
@property(nonatomic, copy) void (^completion)(NSData *);
@property(nonatomic) BOOL finished;
@end
@implementation TrustedCallerAvatarLoader
+ (NSURL *)safeURL:(id)value {
    if (![value isKindOfClass:NSString.class] || [value length] > 2048 ||
        [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    return [parts.scheme.lowercaseString isEqual:@"https"] && parts.host.length &&
        !parts.user && !parts.password ? parts.URL : nil;
}
+ (void)loadValue:(id)value completion:(void (^)(NSData *))completion {
    NSURL *url = [self safeURL:value];
    if (!url) { completion(nil); return; }
    TrustedCallerAvatarLoader *loader = [self new];
    loader.completion = completion;
    loader.bytes = [NSMutableData data];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.URLCredentialStorage = nil; config.HTTPCookieStorage = nil;
    config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 5;
    NSOperationQueue *queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
    loader.session = [NSURLSession sessionWithConfiguration:config delegate:loader delegateQueue:queue];
    [[loader.session dataTaskWithURL:url] resume];
    __weak TrustedCallerAvatarLoader *weak = loader;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [weak finish:nil]; });
}
- (void)finish:(NSData *)image {
    void (^reply)(NSData *);
    @synchronized (self) {
        if (self.finished) return;
        self.finished = YES; reply = self.completion; self.completion = nil;
        [self.session invalidateAndCancel]; self.session = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ if (reply) reply(image); });
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    if (![self.class safeURL:request.URL.absoluteString]) { completionHandler(nil); [self finish:nil]; }
    else completionHandler(request);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
    didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
    if (!http || http.statusCode < 200 || http.statusCode >= 300 || response.expectedContentLength > 2 * 1024 * 1024) {
        completionHandler(NSURLSessionResponseCancel); [self finish:nil];
    } else completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (data.length > 2 * 1024 * 1024 - self.bytes.length) { [self finish:nil]; return; }
    [self.bytes appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error || !self.bytes.length) { [self finish:nil]; return; }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)self.bytes, NULL);
    if (!source) { [self finish:nil]; return; }
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    NSUInteger width = [properties[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger height = [properties[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    CGImageRef thumbnail = width > 0 && height > 0 && width <= 4096 && height <= 4096 ?
        CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@{
            (id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
            (id)kCGImageSourceCreateThumbnailWithTransform:@YES,
            (id)kCGImageSourceThumbnailMaxPixelSize:@128}) : NULL;
    CFRelease(source);
    NSData *data = thumbnail ? UIImageJPEGRepresentation([UIImage imageWithCGImage:thumbnail], 0.65) : nil;
    if (thumbnail) CGImageRelease(thumbnail);
    [self finish:data.length > 0 && data.length <= 32768 ? data : nil];
}
@end
