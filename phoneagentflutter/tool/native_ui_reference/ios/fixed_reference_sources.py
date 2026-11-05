"""Read only the fixed UI implementation and its local header dependencies."""
import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], check=True,
                          capture_output=True).stdout


def list_fixed(repo, revision, directory):
    prefix = git(repo, 'rev-parse', '--show-prefix').decode().strip()
    names = git(repo, 'ls-tree', '-r', '--name-only', revision, '--',
                directory).decode().splitlines()
    return [name.removeprefix(prefix) for name in names]


def export_fixed(repo, revision, destination, implementations, include_dirs):
    """Export explicit .m files and recursively referenced .h files, no checkout."""
    prefix = git(repo, 'rev-parse', '--show-prefix').decode().strip()
    available = set()
    for directory in include_dirs:
        available.update(list_fixed(repo, revision, directory))
    pending = list(implementations)
    exported = {}
    while pending:
        relative = pending.pop()
        path = PurePosixPath(relative)
        if path.is_absolute() or '..' in path.parts or path.suffix not in {'.m', '.h'}:
            raise ValueError('Invalid fixed UI source path')
        if relative in exported:
            continue
        if relative not in available:
            raise ValueError('Fixed UI source outside declared include directories')
        raw = git(repo, 'show', revision + ':' + prefix + relative)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
        exported[relative] = hashlib.sha256(raw).hexdigest()
        imports = re.findall(rb'^\s*#\s*(?:import|include)\s*["<]([^">]+)[">]', raw, re.M)
        for imported in imports:
            name = imported.decode()
            candidates = [str(path.parent / name),
                          *[str(PurePosixPath(directory) / name) for directory in include_dirs]]
            # System/framework headers are absent from the allowed fixed tree.
            found = next((item for item in candidates if item in available), None)
            if found is not None and found.endswith('.h'):
                pending.append(found)
    return exported
