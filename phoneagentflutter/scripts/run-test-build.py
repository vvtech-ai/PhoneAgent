#!/usr/bin/env python3
"""Run build, platform verification and export; clean only this run's workspace."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from test_build_workspace import Artifact, WorkspaceError, run_pipeline
from ios_invite_config import ENVIRONMENTS


def verify_ios_artifacts(workspace, artifacts, environment, repo):
    for item in artifacts:
        if Path(item.source).suffix.lower() == '.ipa':
            if environment not in ENVIRONMENTS:
                raise WorkspaceError('导出 IPA 必须显式提供 --ios-environment。')
            subprocess.run([
                sys.executable, '-B', str(repo / 'scripts/verify_ios_invite_artifact.py'),
                '--environment', environment, '--artifact', str(workspace / item.source),
            ], check=True)
            paired = next((a for a in artifacts if a.source == item.source + '.build.json'
                           and a.name == item.name + '.build.json'), None)
            if paired:
                from ios_build_manifest import load_manifest, validate_package
                manifest = load_manifest(workspace / paired.source)
                validate_package(workspace / item.source, workspace / paired.source, environment,
                                 manifest['version']['name'], manifest['version']['number'],
                                 manifest['artifact']['sha256'], artifact_name=item.name)


def command(value):
    try:
        result = json.loads(value)
        if not isinstance(result, list) or not result or not all(isinstance(x, str) and x for x in result):
            raise ValueError()
        return result
    except (ValueError, TypeError):
        raise argparse.ArgumentTypeError('命令必须为非空JSON字符串数组。') from None


def artifact(value):
    try:
        result = json.loads(value)
        if not isinstance(result, dict) or set(result) != {'source', 'name'}:
            raise ValueError()
        if not all(isinstance(x, str) and x for x in result.values()):
            raise ValueError()
        output = Artifact(**result)
        output.validate()
        return output
    except (ValueError, TypeError, WorkspaceError):
        raise argparse.ArgumentTypeError('产物必须声明有效的source与name。') from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-command', type=command, required=True)
    parser.add_argument('--verify-command', type=command, required=True)
    parser.add_argument('--artifact', type=artifact, action='append', required=True)
    parser.add_argument('--ios-environment', choices=ENVIRONMENTS)
    options = parser.parse_args()
    if (any(Path(item.source).suffix.lower() == '.ipa' for item in options.artifact)
            and options.ios_environment is None):
        parser.error('导出 IPA 必须显式提供 --ios-environment。')
    for item in options.artifact:
        if Path(item.name).suffix.lower() == '.ipa' and not any(
                a.name == item.name + '.build.json' and a.source == item.source + '.build.json'
                for a in options.artifact):
            parser.error('导出 IPA 必须同时声明对应 .ipa.build.json 清单。')
    repo = Path(__file__).resolve().parent.parent

    def phase(argv):
        def run(workspace):
            args = [x.replace('{workspace}', str(workspace)).replace('{repo}', str(repo)) for x in argv]
            subprocess.run(args, cwd=workspace, check=True)
        return run

    try:
        def verify(workspace):
            phase(options.verify_command)(workspace)
            verify_ios_artifacts(workspace, options.artifact, options.ios_environment, repo)

        run_pipeline(repo, phase(options.build_command), verify, options.artifact)
        return 0
    except KeyboardInterrupt:
        print('打包已中断，未完成目录保留。', file=sys.stderr)
        return 130
    except (WorkspaceError, OSError, subprocess.CalledProcessError):
        print('构建、验证或导出失败，未执行清理。', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
