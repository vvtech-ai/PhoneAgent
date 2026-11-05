"""Compile the actual availability branch and assert Flutter Boolean NSNumber types."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
text = (root / 'ios/TrustedCallerSDK/Classes/TrustedCallerPlugin.m').read_text()
start = text.index('    if ([call.method isEqual:@"incomingEventsAvailable"]) {')
end = text.index('    if ([call.method isEqual:@"updateAccount"])', start)
branch = text[start:end]
source = r'''
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
@interface Call : NSObject
@property(nonatomic,copy) NSString *method;
@property(nonatomic,strong) id arguments;
@end
@implementation Call
@end
static BOOL linked;
@interface TrustedCallerSDKAvailability : NSObject
+ (NSString *)sdkEnvironment;
+ (BOOL)isDeviceSDKLinked;
@end
@implementation TrustedCallerSDKAvailability
+ (NSString *)sdkEnvironment { return @"test"; }
+ (BOOL)isDeviceSDKLinked { return linked; }
@end
static void handle(Call *call, void (^result)(id)) {
''' + branch + r'''
}
int main() {
 @autoreleasepool {
  NSArray *args = @[@{@"environment":@"test"}, @{@"environment":@"pro"}, @{}, @"invalid"];
  for (id arguments in args) for (int state=0;state<2;state++) {
   linked=state; Call *call=[Call new];call.method=@"incomingEventsAvailable";call.arguments=arguments;
   __block NSUInteger replies=0;
   handle(call, ^(id value) {
    replies++;
    NSCAssert([value isKindOfClass:NSNumber.class] &&
      CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID(), @"Must encode Boolean, never integer 0/1");
    BOOL expected=[arguments isKindOfClass:NSDictionary.class] &&
      [arguments[@"environment"] isEqual:@"test"] && linked;
    NSCAssert([value boolValue]==expected,@"Correct linked/environment decision");
   });
   NSCAssert(replies==1,@"Exactly one reply");
  }
  puts("Actual incoming availability branch: 8 Boolean wire-type and environment cases passed");
 }
}
'''
with tempfile.TemporaryDirectory(prefix='phoneagent-availability-') as temp:
    src = Path(temp) / 'probe.m'
    binary = Path(temp) / 'probe'
    src.write_text(source)
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-framework',
                    'Foundation', str(src), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
