"""Prepare authorized reference configuration; never print credentials."""
import json
from pathlib import Path
import re
import subprocess

from prepare_trusted_caller_credentials import write_private

ANDROID_REF = '0f8879e4baf1d56fe6d7f8f356101fdf61d602ed'
IOS_REF = 'bb9ff34966f40a3c2794a9a8b8e935669a9faa12'


def source(repo, ref, path):
    return subprocess.check_output(['git', '-C', str(repo), 'show', ref + ':' + path],
                                   stderr=subprocess.DEVNULL).decode()


def extract(android, ios, properties=None):
    properties = properties or {}
    result = {}
    for provider, stem, prefix, model_suffix, rate in [
        ('QWEN', 'qwen', 'QWEN', 'Model', 24000),
        ('DOUBAO', 'doubao', 'DOUBAO', 'ResourceId', 16000),
    ]:
        values = {}
        for suffix in ['Url', 'ApiKey', model_suffix] + (['AccessKey'] if provider == 'DOUBAO' else []):
            match = re.search(r'def ' + stem + 'Realtime' + suffix +
                              r'\s*=\s*localOrProjectProperty\(\s*"([^"]*)",\s*("(?:\\.|[^"\\])*")', android)
            if not match:
                raise ValueError('Reference Android field missing')
            value = properties.get(match[1], '').strip() or json.loads(match[2])
            ios_suffix = {'Url': 'URL', 'ApiKey': 'API_KEY', 'AccessKey': 'ACCESS_KEY',
                          'Model': 'MODEL', 'ResourceId': 'RESOURCE_ID'}[suffix]
            fallback = re.search(r'AITranslationConfigString\(@"ASSISTANT_' + prefix +
                                 '_REALTIME_' + ios_suffix + r'",\s*@("(?:\\.|[^"\\])*")', ios)
            if not fallback:
                raise ValueError('Reference iOS field missing')
            values[suffix] = value or json.loads(fallback[1])
        headers = {'Authorization': 'Bearer ' + values['ApiKey']} if provider == 'QWEN' else {
            'X-Api-Resource-Id': values[model_suffix],
            'X-Api-Key' if values['ApiKey'] else 'X-Api-Access-Key': values['ApiKey'] or values['AccessKey'],
        }
        if not values['ApiKey'] and (provider == 'QWEN' or not values.get('AccessKey')):
            raise ValueError('Reference credentials missing')
        if any(not v.strip() or any(c in v for c in '\r\n\0') for v in headers.values()):
            raise ValueError('Invalid reference header')
        expected = {'QWEN': 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
                    'DOUBAO': 'wss://openspeech.bytedance.com/api/v4/ast/v2/translate'}[provider]
        if values['Url'] != expected or not values[model_suffix].strip():
            raise ValueError('Unapproved model endpoint or empty model')
        result[provider] = {'provider': provider, 'uri': values['Url'], 'model': values[model_suffix],
                            'voice': 'Nofish', 'outputSampleRate': rate, 'headers': headers}
    return result


def generate(root, models):
    for platform, destination in [
        ('android', 'android/app/src/main/assets/domestic-model-configuration.json'),
        ('ios', 'ios/DomesticModelConfiguration/Private/domestic-model-configuration.json'),
    ]:
        body = json.dumps({'version': 1, 'platform': platform, 'models': models}) + '\n'
        if len(body.encode()) > 16384:
            raise ValueError('Private configuration exceeds limit')
        write_private(root, destination, body)


def main():
    android_repo = Path('/Users/Eason/Desktop/Git/AIAssistant1')
    ios_repo = Path('/Users/Eason/Desktop/Git/AIAssistant')
    properties = {}
    local = android_repo / 'android/local.properties'
    if local.is_file() and not local.is_symlink():
        for line in local.read_text().splitlines():
            if line.startswith('assistant') and '=' in line:
                key, value = line.split('=', 1)
                properties[key.strip()] = value.strip()
    models = extract(
        source(android_repo, ANDROID_REF, 'android/app/build.gradle'),
        source(ios_repo, IOS_REF, 'iOS/PhoneAgent/PhoneAgent/Core/Voice/Translation/AIQwenRealtimeTranslationProtocol.m'),
        properties,
    )
    generate(Path(__file__).resolve().parents[1], models)
    print('Two private platform model configurations prepared; credentials not printed.')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Model configuration preparation failed; values not printed.') from None
