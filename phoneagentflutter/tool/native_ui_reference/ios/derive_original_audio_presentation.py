"""Export fixed original-audio display bytes with memory-only preference ports."""
import hashlib
from pathlib import Path
from fixed_reference_sources import git

SETTINGS = 'PhoneAgent/PhoneAgent/Features/Settings/AISettingsViewController.m'
COMMON = 'PhoneAgent/PhoneAgent/Core/Utilities/UIViewController+AICommon.m'
COLORS = 'PhoneAgent/PhoneAgent/Core/Constants/AIAppConstants.m'
MARKERS = {
    'header': (SETTINGS, 'static UIView *AISettingsPageHeader(',
               '@interface AISettingsContactMethodsViewController :'),
    'clamp': (SETTINGS, 'static NSInteger AISettingsClampTranslationPercent(NSInteger value, NSInteger minValue, NSInteger maxValue, NSInteger step) {',
              'static NSString *AISettingsNormalizedRealtimeProviderId(NSString *provider) {'),
    'audio': (SETTINGS, '@interface AISettingsOriginalAudioToggle :',
              '#pragma mark - Settings Voice Clone Helpers'),
    'base': (COMMON, '- (void)ai_applyBaseScreenStyle {',
             '- (void)ai_prepareAccessibilityModalWithBackdropView:'),
    'background': (COLORS, 'UIColor * AIAppBackgroundColor(void) {', '\n}\n'),
    'text': (COLORS, 'UIColor * AIAppPrimaryTextColor(void) {', '\n}\n'),
}


def extract_original_audio_presentation(repo, revision, output):
    prefix = git(repo, 'rev-parse', '--show-prefix').decode().strip()
    originals = {path: git(repo, 'show', revision + ':' + prefix + path)
                 for path in {entry[0] for entry in MARKERS.values()}}
    sections, ranges = {}, {}
    for name, (path, start, end) in MARKERS.items():
        raw, first, last = originals[path], start.encode(), end.encode()
        if raw.count(first) != 1:
            raise ValueError('Original-audio marker is not unique: ' + name)
        begin = raw.index(first)
        if name in {'background', 'text'}:
            finish = raw.index(last, begin) + len(last)
        else:
            if raw.count(last) != 1:
                raise ValueError('Original-audio end marker is not unique: ' + name)
            finish = raw.index(last)
        if finish <= begin:
            raise ValueError('Original-audio range is reversed: ' + name)
        sections[name] = raw[begin:finish]
        ranges[name] = {'path': prefix + path, 'start': begin, 'end': finish,
                        'sha256': hashlib.sha256(sections[name]).hexdigest()}
    declarations = b'''// Generated reference declarations; no business controller imports.
#import <UIKit/UIKit.h>
@interface AISettingsOriginalAudioViewController : UIViewController
@end
'''
    adapters = b'''
// Simulator host ports: process-local memory, no ordinary preferences or UI shell.
static BOOL referenceEnabled = YES;
static NSInteger referenceVolume = 100, referenceGain = 50;
static BOOL AISettingsTranslationOriginalAudioEnabled(void) { return referenceEnabled; }
static void AISettingsSetTranslationOriginalAudioEnabled(BOOL value) { referenceEnabled = value; }
static NSInteger AISettingsTranslationOriginalAudioVolumePercent(void) { return referenceVolume; }
static void AISettingsSetTranslationOriginalAudioVolumePercent(NSInteger value) { referenceVolume = value; }
static NSInteger AISettingsTranslationOriginalAudioGainPercent(void) { return referenceGain; }
static void AISettingsSetTranslationOriginalAudioGainPercent(NSInteger value) { referenceGain = value; }
static void AISettingsSetBottomContainerVisible(UIViewController *controller, BOOL visible) {}
static void AISettingsSetAssistantFloatingButtonVisible(UIViewController *controller, BOOL visible) {}
@interface UIViewController (OriginalAudioReferenceStyle)
- (void)ai_applyBaseScreenStyle;
@end
'''
    source = (b'// Generated fixed presentation plus explicitly isolated host ports.\n'
              b'#import "GeneratedOriginalAudioPresentation.h"\n'
              b'#import <Masonry/Masonry.h>\n#import <math.h>\n'
              + sections['background'] + sections['text'] + sections['clamp']
              + adapters + sections['header']
              + b'\n@implementation UIViewController (OriginalAudioReferenceStyle)\n'
              + sections['base'] + b'\n@end\n' + sections['audio'])
    for forbidden in [b'NSUserDefaults', b'NSURL', b'NSFileManager', b'AVAudio',
                      b'KXSDK', b'AIAccount', b'AIDeviceIdentity', b'NSNotificationCenter']:
        if forbidden in source:
            raise ValueError('Business dependency in original-audio display')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    generated = {}
    for name, value in [('GeneratedOriginalAudioPresentation.h', declarations),
                        ('GeneratedOriginalAudioPresentation.m', source)]:
        (output / name).write_bytes(value)
        generated[name] = hashlib.sha256(value).hexdigest()
    return {'original_sources': {prefix + path: hashlib.sha256(raw).hexdigest()
                                 for path, raw in originals.items()},
            'ranges': ranges, 'generated_sha256': generated}
