import cxxElementaryAudio

@main
struct MyApp {
    static func main() {
        var runtime = ElemRuntime()

        var node = CustomNode(1, 44100, 512)
        _ = node.setPropertyWrapper("value", 0.8)

        let numSamples = 1024
        var outputBuffer = [Float](repeating: 0.0, count: numSamples)

        outputBuffer.withUnsafeMutableBufferPointer { bufferPointer in
            let context = elem.FloatBlockContext(
                inputData: nil,
                numInputChannels: 0,
                outputData: bufferPointer.baseAddress!,
                numSamples: numSamples,
                userData: nil
            )

            node.processWrapper(context)

            var outputPtr = bufferPointer.baseAddress
            var outputPtrs = [outputPtr]

            runtime.process(
                nil,
                0,
                &outputPtrs,
                1,
                numSamples
            )
        }

        print("First 5 samples: \(outputBuffer.prefix(5))")
    }
}
