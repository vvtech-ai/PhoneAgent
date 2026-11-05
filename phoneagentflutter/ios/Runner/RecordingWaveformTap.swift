import AVFoundation
import MediaToolbox

/// Samples the AVPlayer track without changing the audio passed to the output.
final class RecordingWaveformTap {
  private var floatPCM = false
  private var lastEmission = 0.0
  private let receive: ([Double]) -> Void
  init(receive: @escaping ([Double]) -> Void) { self.receive = receive }

  func mix(track: AVAssetTrack) -> AVAudioMix? {
    let retained = Unmanaged.passRetained(self)
    var callbacks = MTAudioProcessingTapCallbacks(
      version: kMTAudioProcessingTapCallbacksVersion_0,
      clientInfo: retained.toOpaque(),
      init: { _, info, storage in storage.pointee = info },
      finalize: { tap in
        Unmanaged<RecordingWaveformTap>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
      },
      prepare: { tap, _, format in
        let meter = Unmanaged<RecordingWaveformTap>.fromOpaque(
          MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
        meter.floatPCM = format.pointee.mFormatID == kAudioFormatLinearPCM &&
          format.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 &&
          format.pointee.mBitsPerChannel == 32
      },
      unprepare: nil,
      process: { tap, frames, _, buffers, framesOut, flagsOut in
        guard MTAudioProcessingTapGetSourceAudio(tap, frames, buffers,
          flagsOut, nil, framesOut) == noErr else { return }
        let meter = Unmanaged<RecordingWaveformTap>.fromOpaque(
          MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
        meter.sample(buffers)
      })
    var result: MTAudioProcessingTap?
    let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks,
      kMTAudioProcessingTapCreationFlag_PostEffects, &result)
    guard status == noErr, let tap = result else {
      retained.release()
      return nil
    }
    let parameters = AVMutableAudioMixInputParameters(track: track)
    parameters.audioTapProcessor = tap
    let mix = AVMutableAudioMix()
    mix.inputParameters = [parameters]
    return mix
  }

  private func sample(_ pointer: UnsafeMutablePointer<AudioBufferList>) {
    let now = Date.timeIntervalSinceReferenceDate
    guard floatPCM, now - lastEmission >= 1.0 / 15.0 else { return }
    lastEmission = now
    var sums = [Double](repeating: 0, count: 24)
    var counts = [Int](repeating: 0, count: 24)
    for buffer in UnsafeMutableAudioBufferListPointer(pointer) {
      guard let data = buffer.mData else { continue }
      let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
      let samples = data.assumingMemoryBound(to: Float.self)
      for i in 0..<count {
        let bar = min(23, i * 24 / max(1, count))
        let value = Double(samples[i])
        if value.isFinite { sums[bar] += value * value; counts[bar] += 1 }
      }
    }
    let levels = (0..<24).map { sqrt(sums[$0] / Double(max(1, counts[$0]))) * 1.5 }
    DispatchQueue.main.async { [weak self] in self?.receive(levels) }
  }
}
