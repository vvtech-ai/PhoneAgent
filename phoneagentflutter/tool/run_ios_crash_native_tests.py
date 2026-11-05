"""macOS-only projection/store test; accepts the pinned macOS framework slice."""
import argparse
import pathlib
import platform
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--framework', required=True, type=pathlib.Path)
    args = parser.parse_args()
    if platform.system() != 'Darwin':
        parser.error('Requires macOS and Xcode; Windows is not a native test pass.')
    framework = args.framework.resolve()
    if framework.name != 'CrashReporter.framework' or not framework.is_dir():
        parser.error('Pass the macOS CrashReporter.framework from PLCrashReporter 1.12.0.')
    repo = pathlib.Path(__file__).resolve().parent.parent
    sources = repo / 'ios/CrashDiagnostics/Classes'
    with tempfile.TemporaryDirectory(prefix='phoneagent-crash-test-') as temp:
        output = pathlib.Path(temp) / 'crash-test'
        subprocess.run([
            'xcrun', '--sdk', 'macosx', 'clang', '-fobjc-arc', '-fblocks',
            '-I', str(sources), '-F', str(framework.parent),
            str(repo / 'tool/ios_crash_diagnostics_test.m'),
            str(sources / 'PACrashStore.m'), str(sources / 'PACrashProjection.m'),
            str(sources / 'PAIdentityTraceStore.m'),
            str(sources / 'PAIdentityTraceScope.m'),
            str(sources / 'PACrashAccountBinding.m'),
            str(repo / 'tool/ios_identity_trace_store_test.m'),
            '-framework', 'Foundation', '-framework', 'CrashReporter', '-lc++',
            '-o', str(output),
        ], check=True)
        subprocess.run([str(output)], check=True)


if __name__ == '__main__':
    main()
