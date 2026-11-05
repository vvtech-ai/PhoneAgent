"""Extract fixed UIKit display bytes; never compile the service controller."""
import hashlib
from pathlib import Path
from fixed_reference_sources import git

CONTROLLER = 'PhoneAgent/PhoneAgent/Features/Auth/AIInitializationViewController.m'
MARKERS = [
    ('action', 'typedef NS_ENUM(NSInteger, AIInitializationStep)',
     '@interface AIInitializationViewController ()'),
    ('layout', '- (void)buildLayout {', '- (void)loadProviderCatalogs {'),
    ('identity', '- (void)addHeading:', '#pragma mark - Keyboard avoidance'),
    ('cards', '- (UIView *)fieldGroupWithLabel:', '- (void)updateActionButton {'),
]


def extract_initialization_presentation(repo, revision, output):
    prefix = git(repo, 'rev-parse', '--show-prefix').decode().strip()
    raw = git(repo, 'show', revision + ':' + prefix + CONTROLLER)
    sections, ranges = {}, {}
    for name, start, end in MARKERS:
        first, last = start.encode(), end.encode()
        if raw.count(first) != 1 or raw.count(last) != 1:
            raise ValueError('Initialization marker is not unique: ' + name)
        begin, finish = raw.index(first), raw.index(last)
        if finish <= begin:
            raise ValueError('Initialization range is reversed: ' + name)
        sections[name] = raw[begin:finish]
        ranges[name] = {'start': begin, 'end': finish,
                        'sha256': hashlib.sha256(sections[name]).hexdigest()}
    header_bytes = b'''// Generated presentation declarations; synthetic option shape only.
#import <UIKit/UIKit.h>
#import <Masonry/Masonry.h>
@interface AIInitializationProviderOption : NSObject
@property(nonatomic, copy) NSString *providerId, *title, *subtitle, *capability;
@property(nonatomic) BOOL enabled, recommended;
@end
@interface InitializationPresentationReference : UIViewController <UIScrollViewDelegate, UITextFieldDelegate>
@property(nonatomic) NSInteger step;
@property(nonatomic, copy) NSString *identityName, *identityPhone, *identityGender, *errorMessage;
@property(nonatomic, strong) UIView *headerView, *scrollContentView;
@property(nonatomic, strong) UIButton *backButton, *skipButton, *actionButton;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIStackView *stepStack;
@property(nonatomic, strong) MASConstraint *actionButtonBottomConstraint;
@property(nonatomic, strong) UITextField *nameField, *phoneField;
- (void)buildLayout;
- (void)buildIdentityStep;
- (void)buildProviderStepWithTitle:(NSString *)title subtitle:(NSString *)subtitle
    options:(NSArray<AIInitializationProviderOption *> *)options selected:(NSString *)selected;
@end
'''
    source_bytes = (b'// Generated fixed display bytes. No original controller lifecycle/actions.\n'
                    b'#import "GeneratedInitializationPresentation.h"\n#import <objc/runtime.h>\n'
                    + sections['action'] + b'\n@implementation AIInitializationProviderOption\n@end\n'
                    b'@implementation InitializationPresentationReference\n'
                    + sections['layout'] + sections['identity'] + sections['cards']
                    + b'\n@end\n')
    for forbidden in [b'AIAccount', b'AIUserIdentity', b'NSURLSession', b'NSFileManager',
                      b'NSNotificationCenter', b'loadProviderCatalogs', b'rebuildStep',
                      b'finishInitialization', b'KXSDK', b'AVAudioSession']:
        if forbidden in source_bytes:
            raise ValueError('Business dependency in initialization display')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    generated = {}
    for name, value in [('GeneratedInitializationPresentation.h', header_bytes),
                        ('GeneratedInitializationPresentation.m', source_bytes)]:
        (output / name).write_bytes(value)
        generated[name] = hashlib.sha256(value).hexdigest()
    return {'original_path': prefix + CONTROLLER,
            'original_sha256': hashlib.sha256(raw).hexdigest(),
            'ranges': ranges, 'generated_sha256': generated}
