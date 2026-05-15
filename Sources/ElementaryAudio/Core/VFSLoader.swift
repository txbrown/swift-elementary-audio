//
//  VFSLoader.swift
//  ElementaryAudio
//
//  Loads audio files into the Elementary Runtime's shared resource map
//  via AVFoundation for deinterleaved float32 buffer loading.
//

import AVFoundation
import cxxElementaryAudio

/// Loads audio files into the Elementary Runtime's shared resource map.
///
/// The VFS is how `el.sample({ path: "kick", mode: "trigger" })` finds its audio data.
/// Load files by key, then reference them by that key in the graph DSL.
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

        return loadFromPCMBuffer(runtime: runtime, key: key, buffer: buffer, numChannels: numChannels, numSamples: numSamples)
    }

    /// Run garbage collection on the runtime to prune unreferenced VFS resources.
    public static func gc() {
        ElemRuntime.getInstance().gc()
    }

    // MARK: - Private

    /// Copies deinterleaved channel data from the PCM buffer into the runtime's shared resource map.
    private static func loadFromPCMBuffer(
        runtime: ElemRuntime,
        key: String,
        buffer: AVAudioPCMBuffer,
        numChannels: Int,
        numSamples: Int
    ) -> Bool {
        guard let floatChannelData = buffer.floatChannelData else { return false }

        // Allocate temporary per-channel buffers for C++ interop.
        // addAudioBuffer copies data into AudioBufferResource, so we
        // deallocate these after the call returns.
        var channelBuffers: [UnsafeMutablePointer<Float>] = []
        for ch in 0..<numChannels {
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: numSamples)
            ptr.initialize(from: floatChannelData[ch], count: numSamples)
            channelBuffers.append(ptr)
        }

        defer {
            for ptr in channelBuffers {
                ptr.deallocate()
            }
        }

        // Build pointer array for the float** parameter
        var channelPtrs: [UnsafeMutablePointer<Float>?] = channelBuffers.map { Optional($0) }
        return channelPtrs.withUnsafeMutableBufferPointer { buf in
            runtime.addAudioBuffer(
                std.string(key),
                buf.baseAddress!,
                numChannels,
                numSamples
            )
        }
    }
}