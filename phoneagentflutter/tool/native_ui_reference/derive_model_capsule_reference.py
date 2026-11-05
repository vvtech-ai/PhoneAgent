"""Expose the fixed native pure model capsule without modifying native sources."""
import hashlib
import subprocess
from pathlib import Path

native = Path('/Users/Eason/Desktop/Git/AIAssistant1/android')
expected = '0f8879e4baf1d56fe6d7f8f356101fdf61d602ed'
assert subprocess.check_output(
    ['git', '-C', str(native), 'rev-parse', 'HEAD'], text=True
).strip() == expected
source = native / ('app/src/main/java/com/vvtech/aiassistant/features/'
                   'assistant_pure_voice/input/PureVoiceInputDock.kt')
subprocess.run(['git', '-C', str(native), 'diff', '--exit-code', '--', str(source)],
               check=True)
text = source.read_text()
start = text.index('@Composable\nprivate fun PureVoiceModelSelectorCapsule(')
end = text.index('\ninternal data class PureVoiceInputDockLayoutMetrics', start)
body = text[start:end].replace(
    'private fun PureVoiceModelSelectorCapsule(',
    'internal fun NativeDockModelCapsule(', 1
)
shape = text[text.index('private val PureVoiceModelSelectorShape ='):].splitlines()[0]
imports = '''import androidx.compose.runtime.Composable
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
'''
output = Path('.local/ui-reference/contacts-skill-source/NativeDockModelCapsule.kt')
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text('package com.vvtech.aiassistant.features.assistant_pure_voice.input\n\n'
                  + imports + '\n' + body + '\n' + shape + '\n')
print('Derived native model UI:', hashlib.sha256(source.read_bytes()).hexdigest(), output)

# Derive only the pure icon controls; never the full dock with attachment/IME IO.
controls = source.with_name('PureVoiceInputDockControls.kt')
subprocess.run(['git', '-C', str(native), 'diff', '--exit-code', '--', str(controls)],
               check=True)
control_text = controls.read_text()
start = control_text.index('@Composable\nprivate fun PureVoiceKeyboardSwitchButton(')
end = control_text.index('\nprivate fun pureVoiceCallModelDisplayName', start)
icon_body = control_text[start:end].replace(
    'private fun PureVoiceKeyboardSwitchButton(',
    'internal fun NativeKeyboardSwitchButton(', 1
).replace('private fun PureVoiceDockIconButton(',
          'internal fun NativeDockIconButton(', 1)
icon_imports = '\n'.join(line for line in control_text.splitlines() if line.startswith('import '))
icon_output = output.with_name('NativeDockIcons.kt')
icon_output.write_text('package com.vvtech.aiassistant.features.assistant_pure_voice.input\n\n'
                       + icon_imports + '\n\n' + icon_body + '\n')
print('Derived native dock icons:', hashlib.sha256(controls.read_bytes()).hexdigest(), icon_output)
