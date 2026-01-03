import Foundation

/// Protocol for implementing custom audio processing nodes in Swift
///
/// `CustomAudioNode` allows you to create custom DSP implementations that
/// integrate with the Elementary Audio runtime. Custom nodes can perform
/// any audio processing operation and are called on the real-time audio thread.
///
/// ## Thread Safety
///
/// - `setProperty(_:value:)` is called from non-real-time threads
/// - `process(context:)` is called from the real-time audio thread
/// - Use atomic operations or lock-free data structures for thread safety
///
/// ## Example
///
/// ```swift
/// struct GainNode: CustomAudioNode {
///     static let nodeType = "customGain"
///     let nodeId = NodeID()
///     var children: [any AudioNode] = []
///     var properties: NodeProperties = ["gain": 1.0]
///
///     private var gain: Float = 1.0
///
///     init() {}
///
///     init(id: NodeID, sampleRate: Double, blockSize: Int) {
///         // Initialize with runtime parameters
///     }
///
///     mutating func setProperty(_ key: String, value: PropertyValue) -> Bool {
///         if key == "gain", let v = value.numberValue {
///             gain = Float(v)
///             return true
///         }
///         return false
///     }
///
///     func process(context: AudioProcessContext) {
///         for i in 0..<context.numSamples {
///             context.outputData[i] = context.inputData[0][i] * gain
///         }
///     }
///
///     mutating func reset() {
///         gain = 1.0
///     }
/// }
/// ```
public protocol CustomAudioNode: AudioNode {
    /// Initialize the node with runtime parameters
    ///
    /// - Parameters:
    ///   - id: The unique node identifier
    ///   - sampleRate: The audio sample rate in Hz
    ///   - blockSize: The processing block size in samples
    init(id: NodeID, sampleRate: Double, blockSize: Int)

    /// Handle a property update
    ///
    /// Called from non-real-time threads when a property value changes.
    /// Use atomic operations to safely communicate with the audio thread.
    ///
    /// - Parameters:
    ///   - key: The property key
    ///   - value: The new property value
    /// - Returns: `true` if the property was recognized and set
    mutating func setProperty(_ key: String, value: PropertyValue) -> Bool

    /// Process a block of audio
    ///
    /// Called from the real-time audio thread. This method must not:
    /// - Allocate memory
    /// - Take locks (mutexes, semaphores)
    /// - Perform I/O operations
    /// - Call into the Objective-C runtime
    ///
    /// - Parameter context: The audio processing context
    func process(context: AudioProcessContext)

    /// Reset the node's internal state
    ///
    /// Called when the audio graph is reset or the node is reinitialized.
    mutating func reset()
}

// MARK: - Audio Process Context

/// Context provided during audio processing
///
/// Contains pointers to input and output buffers along with metadata
/// about the current processing block.
///
/// - Note: This struct uses `@unchecked Sendable` because the audio buffers
///   are only valid during the `process()` call and must not be stored.
public struct AudioProcessContext: @unchecked Sendable {
    /// Pointer to input channel data (array of channel pointers)
    public let inputData: UnsafeBufferPointer<UnsafePointer<Float>>

    /// Pointer to the output buffer
    public let outputData: UnsafeMutablePointer<Float>

    /// Number of samples in this processing block
    public let numSamples: Int

    /// The current sample rate
    public let sampleRate: Double

    /// Creates an audio process context
    public init(
        inputData: UnsafeBufferPointer<UnsafePointer<Float>>,
        outputData: UnsafeMutablePointer<Float>,
        numSamples: Int,
        sampleRate: Double
    ) {
        self.inputData = inputData
        self.outputData = outputData
        self.numSamples = numSamples
        self.sampleRate = sampleRate
    }
}

// MARK: - Default Implementations

extension CustomAudioNode {
    /// Default implementation does nothing
    public mutating func reset() {}
}
