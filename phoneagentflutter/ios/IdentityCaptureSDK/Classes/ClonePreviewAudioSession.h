#import <Flutter/Flutter.h>

@interface ClonePreviewAudioSession : NSObject
+ (void)prepareWithResult:(FlutterResult)result canPrepare:(BOOL (^)(void))canPrepare;
@end
