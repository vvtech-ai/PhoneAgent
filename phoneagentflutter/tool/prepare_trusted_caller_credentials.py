#!/usr/bin/env python3
"""Validate platform-scoped root Properties and generate private iOS inputs."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from trusted_caller_properties import read_credentials


def ios_environment(root: Path, settings: dict, build: bool = False) -> str:
    # Pod targets do not inherit Runner's Flutter xcconfig. Read only its public
    # APP_ENV identity when DART_DEFINES is not supplied by the actual build.
    from ios_invite_config import dart_environment
    encoded = settings.get("DART_DEFINES")
    if encoded is None:
        config = root / "ios/Flutter/Generated.xcconfig"
        entries = [line.partition("=")[2] for line in config.read_text().splitlines()
                   if line.startswith("DART_DEFINES=")] if config.is_file() else []
        if len(entries) > 1:
            raise ValueError("Duplicate Flutter defines")
        encoded = entries[0] if entries else ""
    runtime = dart_environment(encoded)
    environment = settings.get("PHONEAGENT_IOS_ENV", runtime if runtime != "local" else "dev")
    if environment not in {"dev", "test", "prod"}:
        raise ValueError("Invalid iOS environment")
    if runtime != environment and runtime != "local":
        raise ValueError("iOS and Dart environment mismatch")
    if build:
        local_compile = (runtime == "local" and environment == "dev" and
                         settings.get("CODE_SIGNING_ALLOWED") == "NO")
        if runtime != environment and not local_compile:
            raise ValueError("Missing or mismatched iOS APP_ENV")
        if settings.get("CONFIGURATION") == "Release" and environment == "dev":
            raise ValueError("Release dev is not permitted")
        expected_sdk = "pro" if environment == "prod" else "test"
        if settings.get("PHONEAGENT_TRUSTED_SDK_ENV") != expected_sdk:
            raise ValueError("iOS SDK environment mismatch")
    return "pro" if environment == "prod" else environment


def validate_android(root: Path, environment: str) -> None:
    read_credentials(root, "android", environment)
    path = root / f".local/cloud-{environment}/device-defines.json"
    for component in [path, *path.parents]:
        if component == root:
            break
        if component.is_symlink():
            raise ValueError("Redirected Android configuration")
    try:
        config = json.loads(path.read_text())
    except (OSError, ValueError):
        raise ValueError("Missing or invalid Android cloud configuration") from None
    if not isinstance(config, dict) or config.get("APP_ENV") != ("prod" if environment == "pro" else environment):
        raise ValueError("Android cloud environment mismatch")


def write_private(root: Path, relative: str, data: str) -> None:
    path = root / relative
    ignored = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "--quiet", relative],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if ignored.returncode != 0 or path.is_symlink():
        raise ValueError("Credential destination must be ignored and not redirected")
    for parent in path.parents:
        if parent == root:
            break
        if parent.is_symlink():
            raise ValueError("Redirected credential parent")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file() and path.read_text(encoding="utf-8") == data:
        os.chmod(path, 0o600)
        return
    temporary = path.with_suffix(path.suffix + ".private-tmp")
    ignored_temp = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "--quiet", str(temporary.relative_to(root))],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if temporary.is_symlink() or ignored_temp.returncode != 0:
        raise ValueError("Redirected credential temporary destination")
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0)
    with os.fdopen(os.open(temporary, flags, 0o600), "w", encoding="utf-8") as output:
        output.write(data)
    os.chmod(temporary, 0o600)
    temporary.replace(path)


def generate_ios(root: Path, environment: str) -> None:
    credentials = read_credentials(root, "ios", environment)
    write_private(root, "ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.h",
        "#import <Foundation/Foundation.h>\n@interface TrustedCallerLocalCredentials : NSObject\n"
        "+ (NSString *)appKey;\n+ (NSString *)appSecret;\n@end\n")
    sdk_test = 0 if environment == "pro" else 1
    body = ('#import "TrustedCallerLocalCredentials.h"\n'
            f'#if !defined(PHONEAGENT_TRUSTED_SDK_TEST) || PHONEAGENT_TRUSTED_SDK_TEST != {sdk_test}\n'
            '#error "Trusted caller credential and SDK environment mismatch"\n#endif\n'
            '@implementation TrustedCallerLocalCredentials\n')
    for key in ["appKey", "appSecret"]:
        body += f'+ (NSString *){key} {{ return @{json.dumps(credentials[key], ensure_ascii=False)}; }}\n'
    write_private(root, "ios/TrustedCallerSDK/Generated/TrustedCallerLocalCredentials.m", body + "@end\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--android-only", action="store_true")
    mode.add_argument("--ios-only", action="store_true")
    mode.add_argument("--ios-build", action="store_true")
    parser.add_argument("--ios-environment", choices=["dev", "test", "prod"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if not (args.ios_only or args.ios_build):
        validate_android(root, os.environ.get("PHONEAGENT_ANDROID_ENV", "dev"))
    if args.android_only:
        print("Android root Properties validated; no generated source or iOS inputs changed.")
        return
    settings = dict(os.environ)
    if args.ios_environment:
        settings["PHONEAGENT_IOS_ENV"] = args.ios_environment
    generate_ios(root, ios_environment(root, settings, build=args.ios_build))
    print("iOS root Properties prepared; credential values not logged.")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        raise SystemExit("Trusted credential preparation failed; no credential values printed.") from None
