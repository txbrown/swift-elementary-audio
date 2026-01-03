import SwiftUI
import AVFoundation
import ElementaryAudio
import cxxElementaryAudio

struct ContentView: View {
    @StateObject private var audioEngine = SimpleAudioEngine()

    var body: some View {
        VStack(spacing: 32) {
            Text("Elementary Audio")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("iOS Example")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()

            // Frequency control
            VStack(spacing: 8) {
                Text("Frequency: \(Int(audioEngine.frequency)) Hz")
                    .font(.headline)

                Slider(value: $audioEngine.frequency, in: 100...1000) { _ in
                    audioEngine.updateFrequency()
                }
                .tint(.blue)
            }
            .padding(.horizontal, 32)

            // Waveform selector
            Picker("Waveform", selection: $audioEngine.waveform) {
                Text("Sine").tag(0)
                Text("Saw").tag(1)
                Text("Square").tag(2)
                Text("Triangle").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)
            .onChange(of: audioEngine.waveform) { _, _ in
                audioEngine.updateWaveform()
            }

            Spacer()

            // Play/Stop button
            Button(action: {
                if audioEngine.isPlaying {
                    audioEngine.stop()
                } else {
                    audioEngine.play()
                }
            }) {
                Image(systemName: audioEngine.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(audioEngine.isPlaying ? .red : .green)
            }

            Text(audioEngine.isPlaying ? "Playing" : "Stopped")
                .font(.headline)
                .foregroundColor(audioEngine.isPlaying ? .green : .secondary)

            Spacer()
        }
        .padding()
    }
}

// Simple audio engine using our library
@MainActor
class SimpleAudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var frequency: Double = 440
    @Published var waveform: Int = 0

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var customNode: CustomNodeWrapper?

    init() {
        setupAudio()
    }

    private func setupAudio() {
        engine = AVAudioEngine()
        customNode = CustomNodeWrapper(id: 1, sampleRate: 44100, blockSize: 512)

        guard let engine = engine, let customNode = customNode else { return }

        _ = customNode.setProperty("value", value: 0.3)
        _ = customNode.setProperty("frequency", value: Float(frequency))
        _ = customNode.setProperty("waveform", value: Float(waveform))

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        let capturedNode = customNode
        let renderBlock: AVAudioSourceNodeRenderBlock = { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first,
                  let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            let context = elem.FloatBlockContext(
                inputData: nil,
                numInputChannels: 0,
                outputData: ptr,
                numSamples: Int(frameCount),
                userData: nil
            )

            capturedNode.process(context)

            return noErr
        }

        sourceNode = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        if let sourceNode = sourceNode {
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        }
    }

    func play() {
        guard let engine = engine, !isPlaying else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isPlaying = true
        } catch {
            print("Failed to start audio: \(error)")
        }
    }

    func stop() {
        engine?.stop()
        isPlaying = false
    }

    func updateFrequency() {
        _ = customNode?.setProperty("frequency", value: Float(frequency))
    }

    func updateWaveform() {
        _ = customNode?.setProperty("waveform", value: Float(waveform))
    }
}

#Preview {
    ContentView()
}
