"""Owned test-build lifecycle. No API accepts an old workspace for deletion."""
from dataclasses import dataclass
from datetime import datetime
import hashlib
import os
from pathlib import Path
import shutil
import tempfile


class WorkspaceError(Exception):
    pass


def fingerprint(path):
    with path.open('rb') as source:
        digest = hashlib.sha256()
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
        return digest.hexdigest()


def identity(path):
    value = path.lstat()
    return value.st_dev, value.st_ino


@dataclass(frozen=True)
class Artifact:
    source: str
    name: str

    def validate(self):
        relative = Path(self.source)
        if (relative.is_absolute() or '..' in relative.parts or
                Path(self.name).name != self.name or '\\' in self.name or
                not (Path(self.name).suffix.lower() in {'.apk', '.ipa'} or
                     (self.name.endswith('.ipa.build.json') and self.source.endswith('.ipa.build.json'))) or
                relative.suffix.lower() != Path(self.name).suffix.lower()):
            raise WorkspaceError('产物路径或交付文件名无效。')


class OwnedWorkspace:
    def __init__(self, repo):
        self.repo = Path(repo).resolve(strict=True)
        self.local = self.repo / '.local'
        if self.local.is_symlink():
            raise WorkspaceError('临时目录父路径不允许符号链接。')
        self.local.mkdir(mode=0o700, exist_ok=True)
        self.parent_identity = identity(self.local)
        prefix = 'test-build-' + datetime.now().strftime('%Y%m%d_%H%M%S') + '-'
        self.path = Path(tempfile.mkdtemp(prefix=prefix, dir=self.local))
        self.directory_identity = identity(self.path)

    def assert_owned(self):
        if (self.local.is_symlink() or identity(self.local) != self.parent_identity or
                self.path.parent != self.local or not self.path.name.startswith('test-build-') or
                self.path.is_symlink() or not self.path.is_dir() or
                identity(self.path) != self.directory_identity):
            raise WorkspaceError('本次临时目录身份或路径发生变化。')

    def source(self, artifact):
        self.assert_owned()
        artifact.validate()
        source = self.path / artifact.source
        if any(p.is_symlink() for p in [source, *source.parents]
               if p == self.path or self.path in p.parents):
            raise WorkspaceError('产物不允许使用符号链接。')
        if (not source.resolve().is_relative_to(self.path) or
                not source.is_file() or source.stat().st_size == 0):
            raise WorkspaceError('产物缺失、为空或位于本次目录之外。')
        return source

    def cleanup(self):
        self.assert_owned()
        if not shutil.rmtree.avoids_symlink_attacks:
            raise WorkspaceError('当前平台不支持安全目录清理，保留目录。')
        shutil.rmtree(self.path)


def export_artifacts(workspace, artifacts, hashes):
    deliveries = workspace.repo / 'deliveries'
    if deliveries.is_symlink():
        raise WorkspaceError('交付目录不允许符号链接。')
    deliveries.mkdir(exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix=workspace.path.name + '-', dir=deliveries))
    (destination / '.gitignore').write_text('*\n')
    parent_id, destination_id = identity(deliveries), identity(destination)

    def assert_destination():
        if (deliveries.is_symlink() or identity(deliveries) != parent_id or
                destination.is_symlink() or identity(destination) != destination_id or
                destination.resolve().parent != deliveries):
            raise WorkspaceError('交付目录身份或路径发生变化。')

    outputs = []
    for artifact, expected in zip(artifacts, hashes):
        assert_destination()
        source = workspace.source(artifact)
        target = destination / artifact.name
        with tempfile.NamedTemporaryFile(dir=destination, prefix='.partial-', delete=False) as stream:
            temporary = Path(stream.name)
            with source.open('rb') as data:
                shutil.copyfileobj(data, stream)
            stream.flush()
            os.fsync(stream.fileno())
        if fingerprint(temporary) != expected or fingerprint(source) != expected:
            raise WorkspaceError('产物在验证或导出期间发生变化。')
        assert_destination()
        if target.exists() or target.is_symlink():
            raise WorkspaceError('不允许覆盖已有交付文件。')
        temporary.rename(target)
        outputs.append((target, expected))
    # Recheck the complete set before allowing deletion of the workspace.
    assert_destination()
    if any(path.is_symlink() or fingerprint(path) != digest for path, digest in outputs):
        raise WorkspaceError('交付文件完整性校验失败。')
    return outputs


def run_pipeline(repo, build, verify, artifacts, emit=print):
    if not artifacts:
        raise WorkspaceError('必须声明待验证及导出的APK/IPA。')
    for artifact in artifacts:
        artifact.validate()
    for artifact in artifacts:
        if artifact.name.endswith('.ipa.build.json') and not any(
                ipa.name + '.build.json' == artifact.name and ipa.source + '.build.json' == artifact.source
                for ipa in artifacts if ipa.name.endswith('.ipa')):
            raise WorkspaceError('构建清单必须与对应 IPA 同次导出。')
    if len({a.name.casefold() for a in artifacts}) != len(artifacts):
        raise WorkspaceError('交付文件名重复。')
    workspace = OwnedWorkspace(repo)
    try:
        build(workspace.path)
        hashes = [fingerprint(workspace.source(a)) for a in artifacts]
        verify(workspace.path)
        if any(fingerprint(workspace.source(a)) != digest
               for a, digest in zip(artifacts, hashes)):
            raise WorkspaceError('平台验证期间产物发生变化。')
        outputs = export_artifacts(workspace, artifacts, hashes)
    except BaseException:
        emit(f'打包未完成，保留临时目录：{workspace.path}')
        raise
    for path, digest in outputs:
        emit(f'ARTIFACT {path} SHA256 {digest}')
    try:
        workspace.cleanup()
    except Exception:
        emit(f'交付已完成，临时目录未清理：{workspace.path}')
    return outputs
