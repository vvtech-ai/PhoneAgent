"""Compile the actual release method with strict audio graph substitutes.

No microphone, network, real user audio, or Flutter engine is used. This checks
release ordering and retries; actual AVFAudio device acceptance stays separate.
"""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[2] / 'ios/Runner/PcmOutputChannel.swift').read_text()
start = source.index('  private func release(_ output: Output,')
body_start = source.index('{', start)
depth, end = 1, body_start + 1
while depth:
    depth += (source[end] == '{') - (source[end] == '}')
    end += 1
release = source[start:end].replace('private func release', 'func release', 1)
harness = r'''
var events: [String] = []
enum TestError: Error { case unavailable }
final class Player { func stop() { events.append("player.stop") } }
final class Engine {
  var running = true, attached = true
  func stop() { events.append("engine.stop"); running = false }
  func disconnectNodeOutput(_ player: Player) {
    precondition(!running, "disconnect requires a stopped graph in this regression")
    events.append("disconnect")
  }
  func detach(_ player: Player) {
    precondition(!running, "crash regression: detach on running duplex engine")
    precondition(attached, "node detached twice")
    events.append("detach"); attached = false
  }
}
final class Routes { func stop() throws { events.append("routes.stop") } }
final class AVAudioSession {
  enum Options { case notifyOthersOnDeactivation }
  static let shared = AVAudioSession()
  static func sharedInstance() -> AVAudioSession { shared }
  func setActive(_ enabled: Bool, options: [Options]) throws { events.append("session.stop") }
  func setCategory(_ category: Int, mode: Int, options: Int) throws {}
}
enum PcmDuplexSession {
  static var fail = false
  static func release(_ owner: String) throws {
    events.append("duplex.release")
    if fail { throw TestError.unavailable }
  }
}
final class Output {
  let id = "synthetic"
  let player = Player(), engine = Engine()
  var stopped = false, released = false, attached = true, duplex = true
  var pending = 2
  var routes: Routes? = Routes()
  let oldCategory = 0, oldMode = 0, oldOptions = 0
}
final class Channel {
  var current: Output?
  func cancelPending(_ output: Output, _ reason: String) {
    precondition(output.stopped, "callbacks must be invalidated before cancellation")
    events.append("cancel"); output.pending = 0
  }
RELEASE
}
for duplex in [true, false] {
  events = []
  let channel = Channel(), output = Output()
  output.duplex = duplex; channel.current = output
  precondition(channel.release(output))
  precondition(channel.current == nil && output.stopped && output.released)
  precondition(output.pending == 0 && !output.engine.running)
  precondition(events.firstIndex(of: "engine.stop")! < events.firstIndex(of: "detach")!)
  precondition(events.firstIndex(of: "cancel")! < events.firstIndex(of: "player.stop")!)
  precondition(channel.release(output))
  precondition(events.filter { $0 == "detach" }.count == 1)
}
events = []
let channel = Channel(), output = Output()
channel.current = output; PcmDuplexSession.fail = true
precondition(!channel.release(output) && channel.current === output)
PcmDuplexSession.fail = false
precondition(channel.release(output) && channel.current == nil)
precondition(events.filter { $0 == "detach" }.count == 1)
// Failed starts can release ownership even if the node never attached.
events = []
let partial = Output(); partial.attached = false; channel.current = partial
precondition(channel.release(partial))
precondition(!events.contains("detach"))
print("PASS: duplex/ordinary stopped graph, pending cancellation, duplicate stop, retry, partial start")
'''.replace('RELEASE', release)
with tempfile.TemporaryDirectory(prefix='phoneagent-ios-release-') as tmp:
    root = Path(tmp)
    main = root / 'main.swift'
    main.write_text(harness)
    executable = root / 'verify'
    subprocess.run(['xcrun', 'swiftc', str(main), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True, cwd=tmp)
