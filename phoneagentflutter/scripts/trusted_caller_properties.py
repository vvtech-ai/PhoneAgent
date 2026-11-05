"""Private root Properties reader; matches java.util.Properties UTF-8 Reader rules."""
from pathlib import Path
import re


class TrustedConfigurationError(ValueError):
    pass


def decode_property(value):
    output = []
    index = 0
    while index < len(value):
        char = value[index]
        index += 1
        if char == '\\':
            if index == len(value):
                break
            char = value[index]
            index += 1
            if char == 'u':
                digits = value[index:index + 4]
                if len(digits) != 4 or not re.fullmatch('[0-9a-fA-F]{4}', digits):
                    raise TrustedConfigurationError('可信来电 Properties 格式无效。')
                char = chr(int(digits, 16))
                index += 4
            else:
                char = {'t': '\t', 'n': '\n', 'r': '\r', 'f': '\f'}.get(char, char)
        output.append(char)
    # Java strings contain UTF-16 code units; combine escaped surrogate pairs.
    return ''.join(output).encode('utf-16-le', errors='surrogatepass').decode('utf-16-le', errors='surrogatepass')


def parse_properties(text):
    logical_lines = []
    pending = None
    for line in re.split(r'\r\n|\r|\n', text):
        if pending is None:
            line = line.lstrip(' \t\f')
            if not line or line.startswith(('#', '!')):
                continue
        else:
            line = pending + line.lstrip(' \t\f')
        if (len(line) - len(line.rstrip('\\'))) % 2:
            pending = line[:-1]
        else:
            logical_lines.append(line)
            pending = None
    if pending is not None:
        logical_lines.append(pending)
    result = {}
    for line in logical_lines:
        index = 0
        while index < len(line):
            if line[index] == '\\':
                index += 2
            elif line[index] in '=: \t\f':
                break
            else:
                index += 1
        end = index
        index += len(line[index:]) - len(line[index:].lstrip(' \t\f'))
        if index < len(line) and line[index] in '=:':
            index += 1
        value = line[index:].lstrip(' \t\f')
        result[decode_property(line[:end])] = decode_property(value)
    return result


def properties_file(repo):
    path = Path(repo) / 'local.properties'
    if path.is_symlink() or not path.is_file():
        raise TrustedConfigurationError('缺少根目录 local.properties 或路径为符号链接。')
    return path


def read_credentials(repo, platform, environment):
    if platform not in {'android', 'ios'}:
        raise TrustedConfigurationError('可信来电平台仅允许 android/ios。')
    if environment not in {'dev', 'test', 'pro'}:
        raise TrustedConfigurationError('可信来电构建环境仅允许 dev/test/pro。')
    path = properties_file(repo)
    try:
        config = parse_properties(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        raise TrustedConfigurationError('可信来电 local.properties 无法读取或格式无效。') from None
    values = {}
    for field in ['appKey', 'appSecret']:
        key = f'trustedCaller.{platform}.{environment}.{field}'
        value = config.get(key)
        if not value or not value.strip() or any(c in value for c in '\r\n\0'):
            raise TrustedConfigurationError(f'可信来电配置缺少或包含无效字段 {key}。')
        values[field] = value
    return values
