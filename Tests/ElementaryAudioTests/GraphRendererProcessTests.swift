import XCTest
import cxxElementaryAudio
@testable import ElementaryAudio

final class GraphRendererProcessTests: XCTestCase {
    private var renderer: GraphRenderer!

    override func setUp() {
        super.setUp()
        renderer = GraphRenderer()
        renderer.initialize(sampleRate: 44100, blockSize: 512)
    }

    override func tearDown() {
        renderer.reset()
        renderer = nil
        super.tearDown()
    }

    // MARK: - Initialize

    func testInitializeDoesNotCrash() {
        renderer.initialize(sampleRate: 44100, blockSize: 512)
    }

    func testInitializeWithDifferentRates() {
        renderer.initialize(sampleRate: 48000, blockSize: 256)
        renderer.initialize(sampleRate: 96000, blockSize: 1024)
    }

    // MARK: - Process

    func testProcessProducesSilenceWithNoGraph() {
        // Fresh runtime with no graph should produce silence
        let samples = processBlock(numSamples: 512)
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0
        XCTAssertEqual(maxAmp, 0.0, accuracy: 1e-6, "No graph should produce silence")
    }

    func testProcessProducesNonZeroOutputWithSineGraph() throws {
        let graph = AudioGraph {
            El.cycle(440.0)
        }
        try renderer.render(graph)

        // Process a few blocks (first may be activation latency)
        var foundNonZero = false
        for _ in 0..<4 {
            let samples = processBlock(numSamples: 512)
            let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0
            if maxAmp > 0.1 {
                foundNonZero = true
                XCTAssertLessThanOrEqual(maxAmp, 1.0, "Sine wave should be within [-1, 1]")
                break
            }
        }
        XCTAssertTrue(foundNonZero, "Sine wave should produce non-zero output within a few blocks")
    }

    func testProcessOutputStaysInValidRange() throws {
        let graph = AudioGraph {
            El.cycle(440.0) * 0.5
        }
        try renderer.render(graph)

        for _ in 0..<10 {
            let samples = processBlock(numSamples: 512)
            for sample in samples {
                XCTAssertGreaterThanOrEqual(sample, -1.0)
                XCTAssertLessThanOrEqual(sample, 1.0)
            }
        }
    }

    // MARK: - setProperty

    func testSetPropertyDoesNotCrash() throws {
        let constNode = ConstNode(0.25)
        let nodeId = constNode.nodeId
        let rootNode = RootNode(channel: 0, child: constNode)
        let graph = AudioGraph(roots: [rootNode])
        try renderer.render(graph)

        _ = processBlock(numSamples: 512)

        // setProperty should not crash
        renderer.setProperty(nodeId: nodeId, key: "value", value: 0.75)

        _ = processBlock(numSamples: 512)
    }

    func testSetPropertyChangesOutput() throws {
        // Render a const * 1.0 graph so we can observe const changes
        let constNode = ConstNode(0.0)
        let nodeId = constNode.nodeId
        let graph = AudioGraph {
            Signal(constNode)
        }
        try renderer.render(graph)

        // Warm up
        for _ in 0..<3 {
            _ = processBlock(numSamples: 512)
        }

        // Set to a non-zero value
        renderer.setProperty(nodeId: nodeId, key: "value", value: 0.9)

        // Check that output changes within a few blocks
        var foundChanged = false
        for _ in 0..<4 {
            let samples = processBlock(numSamples: 512)
            if Swift.abs(samples[0] - 0.9) < 0.01 {
                foundChanged = true
                break
            }
        }
        XCTAssertTrue(foundChanged, "setProperty should eventually change the output")
    }

    // MARK: - Integration

    func testRenderThenProcessMultipleBlocksDoesNotCrash() throws {
        renderer.initialize(sampleRate: 44100, blockSize: 128)

        let graph = AudioGraph {
            El.cycle(440.0) * 0.5
        }
        try renderer.render(graph)

        for _ in 0..<20 {
            _ = processBlock(numSamples: 128)
        }
    }

    // MARK: - Helpers

    private func processBlock(numSamples: Int) -> [Float] {
        var outputBuffer = [Float](repeating: 0, count: numSamples)
        outputBuffer.withUnsafeMutableBufferPointer { bufPtr in
            var channelPtr: UnsafeMutablePointer<Float>? = bufPtr.baseAddress
            withUnsafeMutablePointer(to: &channelPtr) { channelPtrPtr in
                renderer.process(
                    outputData: channelPtrPtr,
                    outputChannels: 1,
                    numSamples: numSamples
                )
            }
        }
        return outputBuffer
    }
}
