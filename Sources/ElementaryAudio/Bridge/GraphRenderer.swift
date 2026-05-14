import Foundation
import cxxElementaryAudio

/// Renders an AudioGraph to the Elementary Audio runtime
///
/// GraphRenderer converts Swift audio graphs into runtime instructions
/// and sends them to the C++ Elementary Audio runtime for processing.
public final class GraphRenderer: @unchecked Sendable {

    /// Errors that can occur during graph rendering
    public enum RenderError: Error, CustomStringConvertible {
        case runtimeNotAvailable
        case encodingFailed(String)
        case renderFailed(Int32)

        public var description: String {
            switch self {
            case .runtimeNotAvailable:
                return "Elementary Audio runtime is not available"
            case .encodingFailed(let message):
                return "Failed to encode graph: \(message)"
            case .renderFailed(let code):
                return "Runtime render failed with code: \(code)"
            }
        }
    }

    // Track node IDs we've created for cleanup
    private var createdNodeIds: Set<Int32> = []
    // Track root IDs for activation
    private var currentRootIds: [Int32] = []

    /// Creates a new graph renderer
    public init() {}

    /// Renders an audio graph to the runtime
    ///
    /// - Parameter graph: The audio graph to render
    /// - Throws: `RenderError` if rendering fails
    public func render(_ graph: AudioGraph) throws {
        // Garbage-collect nodes from the previous render that have finished fading out
        gc()

        // Encode the graph to instructions
        var encoder = InstructionEncoder()
        encoder.encode(graph)

        let instructions = encoder.allInstructions

        // Get the runtime singleton
        let runtime = ElemRuntime.getInstance()

        // Collect root IDs and send instructions
        var rootIds: [Int32] = []

        for instruction in instructions {
            if instruction.type == .activateRoots, let ids = instruction.rootIds {
                rootIds = ids.map { $0.rawValue }
                continue // Handle activation at the end
            }
            if instruction.type == .commitUpdates {
                continue // Handle commit at the end
            }

            let result = try sendInstruction(instruction, to: runtime)
            if result != 0 {
                throw RenderError.renderFailed(result)
            }

            // Track created nodes
            if instruction.type == .createNode, let nodeId = instruction.nodeId {
                createdNodeIds.insert(nodeId.rawValue)
            }
        }

        // Activate roots and commit
        if !rootIds.isEmpty {
            currentRootIds = rootIds
            let result = activateAndCommit(rootIds, runtime: runtime)
            if result != 0 {
                throw RenderError.renderFailed(result)
            }
        }
    }

    /// Sends a single instruction to the runtime
    private func sendInstruction(_ instruction: InstructionEncoder.Instruction, to runtime: ElemRuntime) throws -> Int32 {
        switch instruction.type {
        case .createNode:
            guard let nodeId = instruction.nodeId,
                  let nodeType = instruction.nodeType else {
                throw RenderError.encodingFailed("CREATE_NODE missing nodeId or nodeType")
            }
            return runtime.createNode(nodeId.rawValue, std.string(nodeType))

        case .appendChild:
            guard let parentId = instruction.nodeId,
                  let childId = instruction.childId else {
                throw RenderError.encodingFailed("APPEND_CHILD missing parentId or childId")
            }
            return runtime.appendChild(parentId.rawValue, childId.rawValue, instruction.childOutputChannel ?? 0)

        case .setProperty:
            guard let nodeId = instruction.nodeId,
                  let key = instruction.propertyKey,
                  let value = instruction.propertyValue else {
                throw RenderError.encodingFailed("SET_PROPERTY missing required fields")
            }

            switch value {
            case .number(let num):
                return runtime.setPropertyNumber(nodeId.rawValue, std.string(key), num)
            case .string(let str):
                return runtime.setPropertyString(nodeId.rawValue, std.string(key), std.string(str))
            case .boolean(let b):
                return runtime.setPropertyBoolean(nodeId.rawValue, std.string(key), b)
            case .array(let arr):
                return arr.withUnsafeBufferPointer { buffer in
                    runtime.setPropertyArray(nodeId.rawValue, std.string(key), buffer.baseAddress, buffer.count)
                }
            case .object:
                // Nested objects are not supported
                return 0
            }

        case .activateRoots, .commitUpdates:
            // Handled separately
            return 0
        }
    }

    /// Activates root nodes and commits updates
    private func activateAndCommit(_ rootIds: [Int32], runtime: ElemRuntime) -> Int32 {
        // Handle empty array case separately to avoid pointer issues
        guard !rootIds.isEmpty else {
            // For empty roots, pass a valid pointer with count 0
            var dummy: Int32 = 0
            return withUnsafePointer(to: &dummy) { ptr in
                runtime.activateRootsAndCommit(ptr, 0)
            }
        }

        // Use Swift array with withUnsafeBufferPointer for C interop
        return rootIds.withUnsafeBufferPointer { buffer in
            runtime.activateRootsAndCommit(buffer.baseAddress, buffer.count)
        }
    }

    /// Clears all nodes from the runtime
    public func clear() {
        // Just clear tracking - nodes will be replaced on next render
        // The runtime handles node replacement internally
        createdNodeIds.removeAll()
        currentRootIds.removeAll()
    }

    /// Runs garbage collection on the runtime, releasing unused nodes
    public func gc() {
        ElemRuntime.getInstance().gc()
    }

    /// Resets the runtime
    public func reset() {
        ElemRuntime.getInstance().reset()
    }

    // MARK: - Runtime Lifecycle & Processing

    /// Reinitializes the runtime with the given sample rate and block size
    ///
    /// Call this before rendering a graph if you need a specific sample rate
    /// or block size different from the default (44100 Hz / 512 samples).
    ///
    /// - Parameters:
    ///   - sampleRate: The sample rate in Hz
    ///   - blockSize: The processing block size in samples
    public func initialize(sampleRate: Double, blockSize: Int) {
        let runtime = ElemRuntime.getInstance()
        runtime.initialize(sampleRate, Int32(blockSize))
        createdNodeIds.removeAll()
        currentRootIds.removeAll()
    }

    /// Sets a numeric property on a rendered node by its ID
    ///
    /// Use this to update controllable const nodes (e.g., tempo, mute)
    /// without re-rendering the entire graph.
    ///
    /// - Parameters:
    ///   - nodeId: The node ID to update
    ///   - key: The property key (e.g., "value")
    ///   - value: The new numeric value
    /// - Returns: 0 on success, non-zero error code on failure
    @discardableResult
    public func setProperty(nodeId: NodeID, key: String, value: Double) -> Int32 {
        let runtime = ElemRuntime.getInstance()
        return runtime.setPropertyNumber(nodeId.rawValue, std.string(key), value)
    }

    /// Processes audio through the rendered graph
    ///
    /// Call this from an audio render callback to generate samples.
    ///
    /// - Parameters:
    ///   - outputData: Array of output channel buffer pointers
    ///   - outputChannels: Number of output channels
    ///   - numSamples: Number of samples to generate
    public func process(
        outputData: [UnsafeMutablePointer<Float>?],
        outputChannels: Int,
        numSamples: Int
    ) {
        var mutableData = outputData
        mutableData.withUnsafeMutableBufferPointer { buf in
            let runtime = ElemRuntime.getInstance()
            runtime.process(nil, 0, buf.baseAddress, outputChannels, numSamples)
        }
    }

    /// Processes audio through the rendered graph (raw pointer variant)
    ///
    /// Call this from an audio render callback to generate samples.
    ///
    /// - Parameters:
    ///   - outputData: Pointer to output channel buffers
    ///   - outputChannels: Number of output channels
    ///   - numSamples: Number of samples to generate
    public func process(
        outputData: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>,
        outputChannels: Int,
        numSamples: Int
    ) {
        let runtime = ElemRuntime.getInstance()
        runtime.process(nil, 0, outputData, outputChannels, numSamples)
    }
}

// MARK: - Convenience Extensions

extension GraphRenderer {
    /// Renders a graph built with the DSL
    ///
    /// - Parameter builder: A closure that builds the audio graph
    /// - Throws: `RenderError` if rendering fails
    public func render(@AudioGraphBuilder _ builder: () -> AudioGraph) throws {
        let graph = builder()
        try render(graph)
    }
}
