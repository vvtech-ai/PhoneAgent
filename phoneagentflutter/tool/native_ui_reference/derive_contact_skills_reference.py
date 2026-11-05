"""Mechanically expose the fixed native private UI; never mutate its repository."""
import hashlib
import subprocess
from pathlib import Path

native = Path('/Users/Eason/Desktop/Git/AIAssistant1/android')
expected = '0f8879e4baf1d56fe6d7f8f356101fdf61d602ed'
assert subprocess.check_output(['git', '-C', str(native), 'rev-parse', 'HEAD'], text=True).strip() == expected
source = native / 'app/src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactSkillSheet.kt'
subprocess.run(['git', '-C', str(native), 'diff', '--exit-code', '--', str(source)], check=True)
text = source.read_text()
imports = text[text.index('import androidx.compose.foundation.background'):text.index('import androidx.lifecycle.compose')]
body = text[text.index('@Composable\nprivate fun AssistantContactSkillSheet('):]
assert body.count('private fun AssistantContactSkillSheet(') == 1
body = body.replace('private fun AssistantContactSkillSheet(', 'internal fun NativeContactSkillSheet(', 1)
output = Path('.local/ui-reference/contacts-skill-source/NativeContactSkillSheet.kt')
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text('package com.vvtech.aiassistant.uireference\n\n' + imports +
                  'import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactSkillOption\n\n' + body)
print('Derived native UI:', hashlib.sha256(source.read_bytes()).hexdigest(), output)
