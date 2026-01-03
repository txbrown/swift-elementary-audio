import AVFoundation
import Foundation

/// A high-level audio engine with async/await lifecycle management
///
/// `AudioEngine` provides a modern Swift API for real-time audio processing
/// using the Elementary Audio runtime. It handles audio I/O setup, graph
/// rendering, and event handling.
///
/// ## Example
///
/// ```swift
/// let engine = try await AudioEngine()
///
/// // Render a simple sine wave
/// try await engine.render {
///     El.cycle(440) * 0.5
/// }
///
/// try await engine.start()
///
/// // Listen for meter events
/// for await event in engine.events() {
///     print("Event: \(event.name) = \(event.value)")
/// }
/// ```
public actor AudioEngine {
    /// The audio engine state
    public enum State: Sendable {
        case stopped
        case starting
        case running
        case stopping
    }

    /// Error types for audio engine operations
    public enum AudioEngineError: Error, Sendable {
        case audioUnitSetupFailed(String)
        case renderFailed(String)
        case invalidState(String)
        case notRunning
    }

    // MARK: - Properties

    private let avEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double
    private let blockSize: Int

    /// The current engine state
    public private(set) var state: State = .stopped

    /// The currently rendered graph
    public private(set) var currentGraph: AudioGraph?

    // MARK: - Initialization

    /// Creates a new audio engine with the specified configuration
    ///
    /// - Parameters:
    ///   - sampleRate: The sample rate in Hz (default: 44100)
    ///   - blockSize: The processing block size in samples (default: 512)
    public init(sampleRate: Double = 44100, blockSize: Int = 512) async throws {
        self.sampleRate = sampleRate
        self.blockSize = blockSize
        try await setupAudioEngine()
    }

    // MARK: - Graph Rendering

    /// Renders an audio graph using the result builder syntax
    ///
    /// - Parameter builder: A closure that builds the audio graph
    ///
    /// ## Example
    /// ```swift
    /// try await engine.render {
    ///     El.cycle(440) * 0.5  // Mono output
    /// }
    ///
    /// // Stereo output
    /// try await engine.render {
    ///     El.cycle(440) * 0.3  // Left
    ///     El.cycle(550) * 0.3  // Right
    /// }
    /// ```
    public func render(@AudioGraphBuilder _ builder: () -> AudioGraph) async throws {
        let graph = builder()
        try await render(graph: graph)
    }

    /// Renders a pre-built audio graph
    ///
    /// - Parameter graph: The audio graph to render
    public func render(graph: AudioGraph) async throws {
        self.currentGraph = graph

        // In a full implementation, this would:
        // 1. Encode the graph into instructions
        // 2. Send instructions to the C++ runtime via applyInstructions()
        // For now, we store the graph for reference
    }

    // MARK: - Lifecycle

    /// Starts the audio engine
    ///
    /// - Throws: `AudioEngineError.invalidState` if already running
    public func start() async throws {
        guard state == .stopped else {
            throw AudioEngineError.invalidState("Cannot start: engine is \(state)")
        }

        state = .starting

        do {
            try avEngine.start()
            state = .running
        } catch {
            state = .stopped
            throw AudioEngineError.audioUnitSetupFailed(error.localizedDescription)
        }
    }

    /// Stops the audio engine
    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        avEngine.stop()
        state = .stopped
    }

    /// Returns whether the engine is currently running
    public var isRunning: Bool {
        state == .running
    }

    // MARK: - Events

    /// Returns an async stream of events from analysis nodes
    ///
    /// Events are emitted by meter, scope, and snapshot nodes in the graph.
    ///
    /// ## Example
    /// ```swift
    /// try await engine.render {
    ///     El.cycle(440).metered(name: "output")
    /// }
    ///
    /// for await event in engine.events() {
    ///     switch event.name {
    ///     case "output":
    ///         print("Level: \(event.value)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public func events() -> AsyncStream<(name: String, value: PropertyValue)> {
        AsyncStream { continuation in
            // In a full implementation, this would poll the C++ runtime's
            // event queue using processQueuedEvents()
            // For now, return an empty stream
            continuation.finish()
        }
    }

    // MARK: - Private Setup

    private func setupAudioEngine() async throws {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        // Create a simple test tone source node
        let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard self != nil else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // In a full implementation, this would call the C++ runtime's process()
            // For now, output silence
            for buffer in ablPointer {
                guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<Int(frameCount) {
                    ptr[i] = 0
                }
            }

            return noErr
        }

        self.sourceNode = sourceNode

        avEngine.attach(sourceNode)
        avEngine.connect(sourceNode, to: avEngine.mainMixerNode, format: format)
    }
}

// MARK: - Convenience Extensions

extension AudioEngine {
    /// Creates and starts an audio engine in one call
    ///
    /// - Parameters:
    ///   - sampleRate: The sample rate in Hz
    ///   - blockSize: The processing block size
    ///   - builder: A closure that builds the audio graph
    /// - Returns: The running audio engine
    public static func start(
        sampleRate: Double = 44100,
        blockSize: Int = 512,
        @AudioGraphBuilder _ builder: () -> AudioGraph
    ) async throws -> AudioEngine {
        let engine = try await AudioEngine(sampleRate: sampleRate, blockSize: blockSize)
        try await engine.render(builder)
        try await engine.start()
        return engine
    }
}
