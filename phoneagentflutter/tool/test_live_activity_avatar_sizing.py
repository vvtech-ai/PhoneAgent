"""Execute the production Swift branch bodies with deterministic image results.
UIKit/ActivityKit rendering still requires iOS build and device evidence.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'ios/Runner/TrustedIdentityActivityManager.swift').read_text()

def function(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end].replace('private func', 'func', 1)

compress = function('  private func compressedAvatar(')
budget = source[source.index('      func fits() -> Bool'):source.index('      do {\n        let created = try Activity.request')]
# The helper uses only Foundation; no calls into the actual SDK or device.
swift = r'''
import Foundation
import CoreGraphics
struct FakeImage { let width: Int; let height: Int }
class UIImage {
  static var sizes: [String: Int] = [:]
  static var attempts: [String] = []
  var cgImage: FakeImage? = FakeImage(width: 128, height: 128)
  init() {}
  convenience init?(data: Data) { if data.isEmpty || data.first == 255 { return nil }; self.init() }
  func draw(in rect: CGRect) {}
  func jpegData(compressionQuality: CGFloat) -> Data? {
    let key = "\(cgImage!.width):\(Int((compressionQuality * 100).rounded()))"
    Self.attempts.append(key)
    guard let count = Self.sizes[key] else { return nil }
    return Data(repeating: 1, count: count)
  }
}
class UIGraphicsRendererFormat {}
class UIGraphicsImageRendererFormat: UIGraphicsRendererFormat { var scale: CGFloat = 3 }
class UIGraphicsImageRenderer {
  let format: UIGraphicsRendererFormat
  let size: CGSize
  init(size: CGSize, format: UIGraphicsImageRendererFormat = UIGraphicsImageRendererFormat()) {
    precondition(format.scale == 1)
    precondition([120, 80, 60].contains(Int(size.width)) && size.width == size.height)
    self.size = size; self.format = format
  }
  func image(actions: (Int) -> Void) -> UIImage {
    actions(0); let image = UIImage()
    image.cgImage = FakeImage(width: Int(size.width), height: Int(size.height)); return image
  }
}
enum SyntheticError: Error { case failed }
struct FakeAttributes: Encodable {
  static var forceFailure = false
  var avatarData: Data
  var padding: String
  func encode(to encoder: Encoder) throws {
    if Self.forceFailure { throw SyntheticError.failed }
    var container = encoder.unkeyedContainer()
    try container.encode(avatarData); try container.encode(padding)
  }
}
struct State: Encodable { let value = 0 }
class Probe {
  var rejects = 0
  var finalAvatar: Data?
  func trace(_ code: String, _ result: String) { rejects += 1 }
'''
swift += compress
swift += '''
  func runBudget(_ data: Data, padding: Int) {
    var attributes = FakeAttributes(avatarData: data, padding: String(repeating: "x", count: padding))
    let state = State()
'''
swift += budget
swift += r'''
    finalAvatar = attributes.avatarData
  }
}
let order = [120,80,60].flatMap { size in [60,35,15].map { "\(size):\($0)" } }
// Every candidate can be the first qualifying result; later candidates must not run.
for (index, chosen) in order.enumerated() {
  let p = Probe(); UIImage.attempts = []
  UIImage.sizes = Dictionary(uniqueKeysWithValues: order.map { ($0, 1700) })
  UIImage.sizes[chosen] = index == 8 ? 1536 : 1400
  let result = p.compressedAvatar(Data([1]))
  precondition(result.count == (index == 8 ? 1536 : 1400))
  precondition(UIImage.attempts == Array(order.prefix(index + 1)))

}
// Reproduce the logged failing 120px image; 80px provides a valid fallback.
let replay = Probe(); UIImage.attempts = []
UIImage.sizes = ["120:60":3255,"120:35":2285,"120:15":1854,"80:60":1537,"80:35":1400]
precondition(replay.compressedAvatar(Data(repeating:1,count:3589)).count == 1400)
precondition(UIImage.attempts == Array(order.prefix(5)))
for sizes: [String:Int] in [Dictionary(uniqueKeysWithValues: order.map { ($0, 1537) }), [:]] {
  let p = Probe(); UIImage.attempts = []; UIImage.sizes = sizes
  precondition(p.compressedAvatar(Data([1])).isEmpty)
  precondition(UIImage.attempts == order)
}
// Encoding failure at an earlier candidate must not prevent subsequent selection.
let encodeRecovery = Probe(); UIImage.attempts = []; UIImage.sizes = ["120:35":1400]
precondition(encodeRecovery.compressedAvatar(Data([1])).count == 1400)
precondition(UIImage.attempts == Array(order.prefix(2)))
for data in [Data(), Data([255]), Data(repeating:1,count:32769)] {
  let p = Probe(); UIImage.attempts = []
  precondition(p.compressedAvatar(data).isEmpty)
  precondition(UIImage.attempts.isEmpty)
}
let fit = Probe(); fit.runBudget(Data(repeating:1,count:1400), padding:0)
precondition(fit.finalAvatar?.count == 1400)
let removed = Probe(); removed.runBudget(Data(repeating:1,count:1400), padding:3000)
precondition(removed.finalAvatar?.isEmpty == true)
let oversized = Probe(); oversized.runBudget(Data(repeating:1,count:1400), padding:5000)
precondition(oversized.rejects == 1 && oversized.finalAvatar == nil)
FakeAttributes.forceFailure = true
let failed = Probe(); failed.runBudget(Data([1]), padding:0)
precondition(failed.rejects == 1 && failed.finalAvatar == nil)
print("Production Swift bodies: all 9 candidates, fixed pixels, short circuit, logged failure replay, input/encode failures and unchanged budget fallback passed")
'''
with tempfile.TemporaryDirectory(prefix='avatar-sizing-') as folder:
    file = Path(folder) / 'main.swift'
    binary = Path(folder) / 'test'
    file.write_text(swift)
    subprocess.run(['xcrun', 'swiftc', str(file), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
