import ElementaryAudio
import Flow
import Foundation

/// Converts ElementaryPatch to AudioGraph for rendering
public struct PatchConverter {

    public enum ConversionError: Error, CustomStringConvertible {
        case missingNodeData(Int)
        case unknownNodeType(String)
        case invalidConnection(String)
        case cycleDetected
        case noOutputNode

        public var description: String {
            switch self {
            case .missingNodeData(let index):
                return "Missing node data for index \(index)"
            case .unknownNodeType(let type):
                return "Unknown node type: \(type)"
            case .invalidConnection(let message):
                return "Invalid connection: \(message)"
            case .cycleDetected:
                return "Cycle detected in graph (use tapIn/tapOut for feedback)"
            case .noOutputNode:
                return "No output node found in patch"
            }
        }
    }

    /// Convert an ElementaryPatch to an AudioGraph
    public static func convert(_ patch: ElementaryPatch) throws -> AudioGraph {
        var converter = PatchConverter(patch: patch)
        return try converter.buildGraph()
    }

    private let patch: ElementaryPatch
    private var builtNodes: [Int: Signal] = [:]
    private var visitStack: Set<Int> = []

    private init(patch: ElementaryPatch) {
        self.patch = patch
    }

    private mutating func buildGraph() throws -> AudioGraph {
        // Find output nodes
        let outputNodes = patch.nodeData.filter { $0.value.nodeType == "out" }

        if outputNodes.isEmpty {
            throw ConversionError.noOutputNode
        }

        // Build each output channel wrapped in RootNode
        var roots: [any AudioNode] = []

        for (channelIndex, (nodeIndex, _)) in outputNodes.sorted(by: {
            ($0.value.propertyValues["channel"] ?? 0) < ($1.value.propertyValues["channel"] ?? 0)
        }).enumerated() {
            let signal = try buildNode(at: nodeIndex)
            // Wrap in RootNode for proper Elementary runtime activation
            let rootNode = RootNode(channel: channelIndex, child: signal)
            roots.append(rootNode)
        }

        return AudioGraph(roots: roots)
    }

    /// Recursively build a node and its inputs
    private mutating func buildNode(at index: Int) throws -> Signal {
        // Check for already built nodes (DAG sharing)
        if let existing = builtNodes[index] {
            return existing
        }

        // Cycle detection
        if visitStack.contains(index) {
            throw ConversionError.cycleDetected
        }
        visitStack.insert(index)

        guard let data = patch.nodeData[index] else {
            throw ConversionError.missingNodeData(index)
        }

        guard let descriptor = NodeRegistry.shared.descriptor(for: data.nodeType) else {
            throw ConversionError.unknownNodeType(data.nodeType)
        }

        // Find input connections for this node
        let inputWires = patch.flowPatch.wires.filter { $0.input.nodeIndex == index }
            .sorted { $0.input.portIndex < $1.input.portIndex }

        // Build input signals
        var inputs: [Signal] = []
        for portIndex in 0..<descriptor.inputs.count {
            if let wire = inputWires.first(where: { $0.input.portIndex == portIndex }) {
                // Connected input - build the source node
                let inputSignal = try buildNode(at: wire.output.nodeIndex)
                inputs.append(inputSignal)
            } else {
                // Unconnected input - use default value
                let defaultValue = descriptor.inputs[portIndex].defaultValue ?? 0
                inputs.append(Signal(defaultValue))
            }
        }

        // Create the signal based on node type
        let signal = try createSignal(
            type: data.nodeType,
            inputs: inputs,
            properties: data.propertyValues
        )

        visitStack.remove(index)
        builtNodes[index] = signal

        return signal
    }

    /// Create a Signal for a given node type
    private func createSignal(
        type: String,
        inputs: [Signal],
        properties: [String: Double]
    ) throws -> Signal {

        switch type {
        // Oscillators
        case "phasor":
            return El.phasor(inputs.first ?? Signal(440))
        case "cycle":
            return El.cycle(inputs.first ?? Signal(440))
        case "blepsaw":
            return El.blepsaw(inputs.first ?? Signal(440))
        case "blepsquare":
            return El.blepsquare(inputs.first ?? Signal(440))
        case "bleptriangle":
            return El.bleptriangle(inputs.first ?? Signal(440))
        case "noise":
            return El.noise()

        // Binary Math (using operators)
        case "add":
            return (inputs[safe: 0] ?? Signal(0)) + (inputs[safe: 1] ?? Signal(0))
        case "sub":
            return (inputs[safe: 0] ?? Signal(0)) - (inputs[safe: 1] ?? Signal(0))
        case "mul":
            return (inputs[safe: 0] ?? Signal(1)) * (inputs[safe: 1] ?? Signal(1))
        case "div":
            return (inputs[safe: 0] ?? Signal(1)) / (inputs[safe: 1] ?? Signal(1))

        // Unary Math
        case "sin":
            return El.sin(inputs.first ?? Signal(0))
        case "cos":
            return El.cos(inputs.first ?? Signal(0))
        case "tan":
            return El.tan(inputs.first ?? Signal(0))
        case "tanh":
            return El.tanh(inputs.first ?? Signal(0))
        case "abs":
            return El.abs(inputs.first ?? Signal(0))
        case "sqrt":
            return El.sqrt(inputs.first ?? Signal(1))
        case "exp":
            return El.exp(inputs.first ?? Signal(0))
        case "ln":
            return El.ln(inputs.first ?? Signal(1))
        case "floor":
            return El.floor(inputs.first ?? Signal(0))
        case "ceil":
            return El.ceil(inputs.first ?? Signal(0))
        case "round":
            return El.round(inputs.first ?? Signal(0))

        // Filters
        case "pole":
            return El.pole(
                inputs[safe: 0] ?? Signal(0.9),
                inputs[safe: 1] ?? Signal(0)
            )
        case "env":
            return El.env(
                inputs[safe: 0] ?? Signal(0.01),
                inputs[safe: 1] ?? Signal(0.1),
                inputs[safe: 2] ?? Signal(0)
            )
        case "svf":
            let modeValue = Int(properties["mode"] ?? 0)
            let mode: El.SVFMode = {
                switch modeValue {
                case 0: return .lowpass
                case 1: return .highpass
                case 2: return .bandpass
                case 3: return .notch
                case 4: return .allpass
                default: return .lowpass
                }
            }()
            return El.svf(
                mode,
                inputs[safe: 0] ?? Signal(1000),
                inputs[safe: 1] ?? Signal(1),
                inputs[safe: 2] ?? Signal(0)
            )

        // Delays
        case "z":
            return El.z(inputs.first ?? Signal(0))
        case "sdelay":
            let size = Int(properties["size"] ?? 512)
            return El.sdelay(size, inputs.first ?? Signal(0))
        case "delay":
            let size = Int(properties["size"] ?? 48000)
            return El.delay(
                size,
                inputs[safe: 0] ?? Signal(0.5),
                inputs[safe: 1] ?? Signal(0)
            )

        // Control
        case "latch":
            return El.latch(
                inputs[safe: 0] ?? Signal(0),
                inputs[safe: 1] ?? Signal(0)
            )
        case "counter":
            return El.counter(inputs.first ?? Signal(0))
        case "seq":
            // Sequencer needs array of values - use default pattern for now
            let values = [0.0, 0.25, 0.5, 0.75, 1.0]
            let hold = properties["hold"] == 1
            let loop = properties["loop"] == 1
            return El.seq(inputs.first ?? Signal(0), values, hold: hold, loop: loop)

        // Analysis (these pass through the signal)
        case "meter":
            let name = "meter_\(UUID().uuidString.prefix(8))"
            return El.meter(name, inputs.first ?? Signal(0))
        case "scope":
            let name = "scope_\(UUID().uuidString.prefix(8))"
            let size = Int(properties["size"] ?? 512)
            return El.scope(name, size: size, inputs.first ?? Signal(0))

        // Feedback
        case "tapIn":
            let name = "tap_\(UUID().uuidString.prefix(8))"
            return El.tapIn(name, inputs.first ?? Signal(0))
        case "tapOut":
            let name = "tap_\(UUID().uuidString.prefix(8))"
            return El.tapOut(name)

        // Utility
        case "const":
            let value = properties["value"] ?? 0
            return Signal(value)
        case "sr":
            return El.sr()
        case "in":
            let channel = Int(properties["channel"] ?? 0)
            return El.input(channel: channel)
        case "out":
            // Output just passes through its input
            return inputs.first ?? Signal(0)

        default:
            throw ConversionError.unknownNodeType(type)
        }
    }
}

// MARK: - Helper Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

