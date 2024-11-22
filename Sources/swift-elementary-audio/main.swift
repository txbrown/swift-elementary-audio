import AVFoundation
import CoreAudio
import cxxElementaryAudio
import ElementaryAudio

@main
struct MyApp {
    static func main() {
        let engine = AudioEngine()

        do {
            try engine.start()
            print("Audio engine running. Press enter to quit...")
        } catch {
            print("Failed to start audio engine:", error)
            exit(1)
        }

        _ = readLine()

        engine.stop()
    }
}

class AudioEngine {
    private let engine = AVAudioEngine()
    private let playerNode: AVAudioSourceNode
    private let runtime: ElemRuntime

    init() {
        runtime = ElemRuntime.getInstance()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        let capturedRuntime: ElemRuntime = runtime

        let renderBlock: AVAudioSourceNodeRenderBlock = { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first else { return noErr }
            guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let node = CustomNodeWrapper(id: 1, sampleRate: 44100, blockSize: 512)
            _ = node.setProperty("value", value: 0.8)

            let outputPtr = ptr
            var outputPtrs: [UnsafeMutablePointer<Float>?] = [outputPtr]

            let context = elem.FloatBlockContext(
                inputData: nil,
                numInputChannels: 0,
                outputData: ptr,
                numSamples: Int(frameCount),
                userData: nil
            )

            node.process(context)

            capturedRuntime.process(
                nil,
                0,
                &outputPtrs,
                1,
                Int(frameCount)
            )

            for i in 0 ... 5 {
                if ptr[i] != 0 {
                    print("Sample[\(i)]: \(ptr[i])")
                }
            }

            return noErr
        }

        playerNode = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        engine.mainMixerNode.outputVolume = 1.0
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        print("\nAVAudioEngine Configuration:")
        print("Main Mixer Output Format:", engine.mainMixerNode.outputFormat(forBus: 0))
        print("Output Node Format:", engine.outputNode.outputFormat(forBus: 0))
    }

    func start() throws {
        try engine.start()
        print("Audio engine started")
    }

    func stop() {
        engine.stop()
        print("Audio engine stopped")
    }
}
