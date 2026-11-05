import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import prepare_domestic_model_configuration as prepare


class ReferenceModelsTest(unittest.TestCase):
    def fixture(self):
        android = ''
        ios = ''
        for stem, prefix, suffix in [('qwen', 'QWEN', 'Model'), ('doubao', 'DOUBAO', 'ResourceId')]:
            url = {'qwen': 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
                   'doubao': 'wss://openspeech.bytedance.com/api/v4/ast/v2/translate'}[stem]
            for field, wire, default in [('Url', 'URL', url), ('ApiKey', 'API_KEY', ''),
                                         (suffix, 'MODEL' if stem == 'qwen' else 'RESOURCE_ID', 'synthetic-model')] + (
                                             [('AccessKey', 'ACCESS_KEY', '')] if stem == 'doubao' else []):
                android += f'def {stem}Realtime{field} = localOrProjectProperty("assistant{stem.title()}Realtime{field}", {json.dumps(default)})\n'
                fallback = default or 'synthetic-private'
                ios += f'AITranslationConfigString(@"ASSISTANT_{prefix}_REALTIME_{wire}", @{json.dumps(fallback)});\n'
        return android, ios

    def test_missing_android_keys_use_ios_and_voice_is_android_default(self):
        models = prepare.extract(*self.fixture())
        self.assertEqual(models['QWEN']['headers'], {'Authorization': 'Bearer synthetic-private'})
        self.assertEqual(models['DOUBAO']['voice'], 'Nofish')
        self.assertEqual(models['QWEN']['outputSampleRate'], 24000)
        self.assertEqual(models['DOUBAO']['outputSampleRate'], 16000)

    def test_android_override_and_invalid_endpoint_or_header(self):
        models = prepare.extract(*self.fixture(), {'assistantQwenRealtimeApiKey': 'synthetic-android'})
        self.assertEqual(models['QWEN']['headers']['Authorization'], 'Bearer synthetic-android')
        for props in [{'assistantQwenRealtimeUrl': 'wss://invalid.example'},
                      {'assistantQwenRealtimeApiKey': 'synthetic\ninvalid'}]:
            with self.assertRaises(ValueError):
                prepare.extract(*self.fixture(), props)

    def test_private_platform_files_ignored_and_no_temporary_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / '.gitignore').write_text('android/\nios/\n')
            prepare.generate(root, prepare.extract(*self.fixture()))
            files = list(root.rglob('domestic-model-configuration.json'))
            self.assertEqual(len(files), 2)
            for path in files:
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(json.loads(path.read_text())['version'], 1)
                self.assertFalse(path.is_symlink())
            self.assertFalse(list(root.rglob('*.private-tmp')))


if __name__ == '__main__':
    unittest.main()
