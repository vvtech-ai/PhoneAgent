"""Compile actual pure Swift admission rules; no audio device or Flutter needed."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[2] / 'ios/Runner/PcmOutputChannel.swift').read_text()
rules = source.split('// BEGIN PCM_TRANSLATION_ADMISSION:')[1].split('\n', 1)[1]
rules = rules.split('// END PCM_TRANSLATION_ADMISSION')[0]
checks = r'''
let state = PcmTranslationAdmission()
var accepted = 0, drained = 0, cancelled = 0
state.enqueue(pendingBytes: 6400, highWater: 16000) { reason in
  precondition(reason == nil); accepted += 1
}
state.enqueue(pendingBytes: 19200, highWater: 16000) { reason in
  precondition(reason == nil); accepted += 1
}
state.drain(pendingBytes: 19200) { reason in
  precondition(reason == nil); drained += 1
}
precondition(accepted == 1 && drained == 0)
state.played(pendingBytes: 12800)
precondition(accepted == 2 && drained == 0) // Admission before the last chunk ends.
state.played(pendingBytes: 6400)
precondition(drained == 0)
state.played(pendingBytes: 0)
precondition(drained == 1)
state.enqueue(pendingBytes: 19200, highWater: 16000) { reason in
  precondition(reason == "output_stalled"); cancelled += 1
}
state.drain(pendingBytes: 19200) { reason in
  precondition(reason == "output_stalled"); cancelled += 1
}
state.cancel("output_stalled")
state.cancel("output_stalled")
state.played(pendingBytes: 0)
precondition(cancelled == 2 && accepted == 2 && drained == 1)
print("PASS: admission before empty, real drain, cancellation exactly once")
'''
with tempfile.TemporaryDirectory(prefix='ios-pcm-admission-') as tmp:
    main = Path(tmp) / 'main.swift'
    main.write_text(rules + checks)
    executable = Path(tmp) / 'verify'
    subprocess.run(['xcrun', 'swiftc', str(main), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
