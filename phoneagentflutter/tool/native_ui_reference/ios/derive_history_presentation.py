"""Extract fixed UIKit presentation bytes; never compile its service controller."""
import hashlib
from pathlib import Path
from fixed_reference_sources import git

CONTROLLER = 'PhoneAgent/PhoneAgent/Features/Calls/AIRealtimeTranslationHistoryViewController.m'


def extract_history_presentation(repo, revision, output):
    prefix = git(repo, 'rev-parse', '--show-prefix').decode().strip()
    raw = git(repo, 'show', revision + ':' + prefix + CONTROLLER)
    ranges = {}

    def section(name, start, end=None):
        first = start.encode()
        if raw.count(first) != 1:
            raise ValueError('History presentation start marker is not unique: ' + name)
        begin = raw.index(first)
        if end is None:
            finish = len(raw)
        else:
            last = end.encode()
            if raw.count(last) != 1:
                raise ValueError('History presentation end marker is not unique: ' + name)
            finish = raw.index(last)
        if finish <= begin:
            raise ValueError('History presentation range is inverted: ' + name)
        data = raw[begin:finish]
        ranges[name] = {'start_byte': begin, 'end_byte': finish,
                        'sha256': hashlib.sha256(data).hexdigest()}
        return data

    colors = section('colors_trim', 'static UIColor *AIRealtimeColor(',
                     'static void *AIRealtimePlayerItemStatusContext')
    declaration = section('bubble_declaration', '@interface AIRealtimeTranscriptBubble : UIView',
                          'typedef NS_ENUM(NSInteger, AIRealtimeRecordingActionGlyph)')
    header_method = section('header_method', '- (UIView *)headerViewForDetail:',
                            '- (NSArray<AIRealtimeTranslationTranscript *> *)validTranscripts:')
    empty = section('empty_subtitle', '        UIView *emptyContainer = [UIView new];',
                    '        [stack addArrangedSubview:emptyContainer];')
    initial_base = section('initial_base', '- (void)buildBaseLayout {', '- (void)loadDetail {')
    initial_loading = section('initial_loading', '- (void)showLoadingState {', '- (void)showErrorStateWithMessage:')
    initial_error = section('initial_error', '- (void)showErrorStateWithMessage:', '- (void)renderDetail:')
    bubble = section('bubble_implementation', '@interface AIRealtimeTranscriptBubble ()')
    generated_header = (b'// Generated fixed presentation declaration.\n'
                        b'#import <UIKit/UIKit.h>\n#import "AIRealtimeTranslationModels.h"\n'
                        + declaration + b'\n@interface HistoryHeaderReference : NSObject\n'
                        b'- (UIView *)headerViewForDetail:(AIRealtimeTranslationDetail *)detail;\n'
                        b'- (UIView *)emptySubtitleView;\n@end\n'
                        b'@interface HistoryInitialStateReference : UIViewController\n'
                        b'@property(nonatomic, strong) UILabel *messageLabel;\n'
                        b'@property(nonatomic, strong) UIButton *retryButton;\n'
                        b'@property(nonatomic, strong) UIStackView *stateStack;\n'
                        b'@property(nonatomic, copy) void (^retryHandler)(void);\n'
                        b'@property(nonatomic, copy) void (^closeHandler)(void);\n'
                        b'- (void)buildBaseLayout;\n- (void)showLoadingState;\n'
                        b'- (void)showErrorStateWithMessage:(NSString *)message;\n@end\n')
    generated_source = (b'// Generated presentation bytes; host fixes time and duration labels.\n'
                        b'#import "GeneratedHistoryPresentation.h"\n'
                        b'#import "AITranslationCallRuntimePolicy.h"\n#import <Masonry/Masonry.h>\n'
                        + colors + b'\nstatic NSString *AIRealtimeHistoryTimeText(NSString *value) { return @"9\xe6\x9c\x8816\xe6\x97\xa5 11:00"; }\n'
                        b'static NSString *AIRealtimeHistoryDuration(long long value) { return @"00:12"; }\n'
                        b'@implementation HistoryHeaderReference\n' + header_method +
                        b'- (UIView *)emptySubtitleView {\n' + empty +
                        b'    return emptyContainer;\n}\n@end\n' + bubble +
                        b'\n// First-state only: no rendered content, services, or original actions.\n'
                        b'@implementation HistoryInitialStateReference\n' + initial_base + initial_loading + initial_error +
                        b'- (void)removeRenderedContent {}\n'
                        b'- (void)loadDetail { if (self.retryHandler) self.retryHandler(); }\n'
                        b'- (void)closeTapped { if (self.closeHandler) self.closeHandler(); }\n@end\n')
    for forbidden in [b'AVAudioSession', b'AIRealtimeTranslationHistoryService',
                      b'NSURLSession', b'NSFileManager', b'UIDocumentPicker']:
        if forbidden in generated_source:
            raise ValueError('Business dependency in extracted presentation')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    header = output / 'GeneratedHistoryPresentation.h'
    source = output / 'GeneratedHistoryPresentation.m'
    header.write_bytes(generated_header)
    source.write_bytes(generated_source)
    return {'original_path': prefix + CONTROLLER, 'original_sha256': hashlib.sha256(raw).hexdigest(),
            'ranges': ranges, 'generated_sha256': {
                header.name: hashlib.sha256(generated_header).hexdigest(),
                source.name: hashlib.sha256(generated_source).hexdigest()}}
