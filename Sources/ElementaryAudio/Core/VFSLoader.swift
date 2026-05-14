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

        let url = URL(fileURLWithPath: filePath)
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

        let numChannels = Int(format.channelCount)
        let numSamples = Int(buffer.frameLength)

        // Build deinterleaved channel data arrays
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

        // Convert to contiguous raw float data for the C++ bridge
        // The AudioBufferResource constructor takes float** channel pointers
        // We need to provide pointers to contiguous channel data
        return channelArrays.withUnsafeMutablePointers { pointers in
            // Create array of UnsafeMutablePointer<Float>? for C interop
            var mutablePointers: [UnsafeMutablePointer<Float>?] = pointers.map { $0 }

            return mutablePointers.withUnsafeMutableBufferPointer { buf in
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
    /// Resources are pruned via `gc()` when they're no longer referenced by the graph.
    public static func unloadAudioFile(key: String) {
        ElemRuntime.getInstance().gc()
    }
}

// MARK: - Array Unsafe Mutable Pointer Helper

private extension Array where Element == [Float] {
    func withUnsafeMutablePointers<R>(
        _ body: ([UnsafeMutablePointer<Float>]) throws -> R
    ) rethrows -> R {
        // Create mutable copies so we can get mutable pointers
        var mutableArrays = self.map { $0 }
        return try mutableArrays.withUnsafeMutableBufferPointers { pointers in
            let basePointers = pointers.map { $0.baseAddress! }
            return try body(basePointers)
        }
    }
}

private extension Array where Element == [Float] {
    func withUnsafeMutableBufferPointers<R>(
        _ body: ([UnsafeMutableBufferPointer<Float>]) throws -> R
    ) rethrows -> R {
        var arrays = self
        var buffers: [UnsafeMutableBufferPointer<Float>] = []
        for i in arrays.indices {
            buffers.append(UnsafeMutableBufferPointer(start: &arrays[i], count: arrays[i].count))
        }
        return try body(buffers)
    }
}