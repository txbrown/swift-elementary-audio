//
//  VFSLoader.swift
//  ElementaryAudio
//
//  Loads audio files into the Elementary Runtime's Virtual File System (VFS).
//  Uses AVFoundation for file loading, then adds the deinterleaved float32
//  data as AudioBufferResource entries via the C++ bridge.
//

import AVFoundation
import cxxElementaryAudio

/// Loads audio files into the Elementary Runtime's VFS (shared resource map).
///
/// The VFS is how `el.sample({ path: "kick", mode: "trigger" })` finds its audio data.
/// You load files by key, then reference them by that key in the graph DSL.
public final class VFSLoader {

    /// Load an audio file from disk and add it to the runtime's shared resource map.
    ///
    /// - Parameters:
    ///   - key: The VFS key (e.g., "808-kick") used in `el.sample({ path: key })`
    ///   - filePath: Absolute path to the audio file (WAV, MP3, FLAC, etc.)
    /// - Returns: `true` if loaded successfully, `false` on error or duplicate key
    @discardableResult
    public static func loadAudioFile(key: String, filePath: String) -> Bool {
        let runtime = ElemRuntime.getInstance()

        // Try loading via AVAudioFile
        guard let url = URL(string: filePath) ?? URL(fileURLWithPath: filePath) as URL? else {
            return false
        }

        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return false
        }

        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard frameCount > 0 else { return false }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return false
        }

        do {
            try audioFile.read(into: buffer, frameCount: frameCount)
        } catch {
            return false
        }

        // Deinterleave and add to VFS
        let numChannels = Int(format.channelCount)
        let numSamples = Int(buffer.frameLength)

        // Build deinterleaved channel data
        var channelArrays: [[Float]] = []
        for ch in 0..<numChannels {
            var channelData = [Float](repeating: 0, count: numSamples)
            if let floatChannelData = buffer.floatChannelData {
                for i in 0..<numSamples {
                    channelData[i] = floatChannelData[ch][i]
                }
            }
            channelArrays.append(channelData)
        }

        // Use the C++ bridge to add to the runtime's shared resource map
        // We need to pass deinterleaved float* pointers
        return channelArrays.withUnsafeBufferPointers { pointers in
            var cPointers = pointers.map { $0.baseAddress! }
            return cPointers.withUnsafeMutableBufferPointer { buf in
                runtime.addAudioBuffer(
                    std.string(key),
                    buf.baseAddress!,
                    numChannels,
                    numSamples
                )
            }
        }
    }

    /// Remove a previously loaded audio resource from the VFS.
    /// Note: Elementary's runtime doesn't expose removeSharedResource in the public API.
    /// Resources are pruned via `gc()` when they're no longer referenced by the graph.
    public static func unloadAudioFile(key: String) {
        // Run GC to clean up unreferenced resources
        ElemRuntime.getInstance().gc()
    }
}

// MARK: - Array Unsafe Buffer Pointer Helper

private extension Array where Element == [Float] {
    func withUnsafeBufferPointers<R>(
        _ body: ([UnsafeBufferPointer<Float>]) throws -> R
    ) rethrows -> R {
        var buffers: [UnsafeBufferPointer<Float>] = []
        for array in self {
            buffers.append(UnsafeBufferPointer(start: array, count: array.count))
        }
        return try body(buffers)
    }
}