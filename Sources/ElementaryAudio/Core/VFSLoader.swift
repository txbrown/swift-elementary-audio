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
public enum VFSLoader {
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
        for ch in 0 ..< numChannels {
            var channelData = [Float](repeating: 0, count: numSamples)
            if let floatChannelData = buffer.floatChannelData {
                for i in 0 ..< numSamples {
                    channelData[i] = floatChannelData[ch][i]
                }
            }
            channelArrays.append(channelData)
        }

        // addAudioBuffer expects float** (mutable channel pointers).
        // The C++ function only reads the data; UnsafeMutablePointer(mutating:) avoids
        // the lifetime issue of escaping inner mutable pointers from nested closures.
        return channelArrays.withUnsafeBufferPointers { pointers in
            var cPointers: [UnsafeMutablePointer<Float>?] = pointers.map {
                UnsafeMutablePointer(mutating: $0.baseAddress!)
            }
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

    /// Triggers garbage collection to prune audio resources no longer referenced by the graph.
    ///
    /// Elementary's C++ runtime does not expose key-based removal of shared resources.
    /// To free a resource, stop referencing its key in the graph, re-render, then call
    /// this method. The runtime will collect entries with a zero reference count.
    public static func pruneUnreferencedResources() {
        ElemRuntime.getInstance().gc()
    }
}

// MARK: - Array Unsafe Buffer Pointer Helper

private extension [[Float]] {
    /// Calls `body` with an array of buffer pointers, each pinned for the duration of the call.
    ///
    /// Uses recursive `withUnsafeBufferPointer` nesting so all channel arrays are
    /// simultaneously pinned when `body` runs. Passing a raw `UnsafeBufferPointer`
    /// constructed outside a `withUnsafeBufferPointer` scope is unsafe because the
    /// array's contiguous storage is only guaranteed valid inside that scope.
    func withUnsafeBufferPointers<R>(
        _ body: ([UnsafeBufferPointer<Float>]) throws -> R
    ) rethrows -> R {
        func recurse(index: Int, into accumulated: inout [UnsafeBufferPointer<Float>]) throws -> R {
            if index == endIndex {
                return try body(accumulated)
            }
            return try self[index].withUnsafeBufferPointer { ptr in
                accumulated.append(ptr)
                defer { accumulated.removeLast() }
                return try recurse(index: index + 1, into: &accumulated)
            }
        }
        var acc: [UnsafeBufferPointer<Float>] = []
        acc.reserveCapacity(count)
        return try recurse(index: startIndex, into: &acc)
    }
}
