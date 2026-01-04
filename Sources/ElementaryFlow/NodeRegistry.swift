import Foundation
import SwiftUI

/// Defines the category of an Elementary node for UI organization
public enum NodeCategory: String, CaseIterable, Sendable {
    case oscillator = "Oscillators"
    case math = "Math"
    case filter = "Filters"
    case delay = "Delays"
    case control = "Control"
    case analysis = "Analysis"
    case feedback = "Feedback"
    case utility = "Utility"

    public var color: Color {
        switch self {
        case .oscillator: return .orange
        case .math: return .blue
        case .filter: return .purple
        case .delay: return .green
        case .control: return .yellow
        case .analysis: return .pink
        case .feedback: return .red
        case .utility: return .gray
        }
    }
}

/// Describes an input port for a node
public struct PortDescriptor: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let defaultValue: Double?

    public init(id: String, name: String, defaultValue: Double? = nil) {
        self.id = id
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// Describes a property (non-signal parameter) for a node
public struct PropertyDescriptor: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let defaultValue: Double
    public let range: ClosedRange<Double>?

    public init(id: String, name: String, defaultValue: Double, range: ClosedRange<Double>? = nil) {
        self.id = id
        self.name = name
        self.defaultValue = defaultValue
        self.range = range
    }
}

/// Complete metadata for an Elementary Audio node type
public struct NodeDescriptor: Sendable, Identifiable {
    public let id: String
    public let nodeType: String
    public let displayName: String
    public let description: String
    public let category: NodeCategory
    public let inputs: [PortDescriptor]
    public let properties: [PropertyDescriptor]
    public let hasOutput: Bool

    public init(
        nodeType: String,
        displayName: String,
        description: String = "",
        category: NodeCategory,
        inputs: [PortDescriptor] = [],
        properties: [PropertyDescriptor] = [],
        hasOutput: Bool = true
    ) {
        self.id = nodeType
        self.nodeType = nodeType
        self.displayName = displayName
        self.description = description
        self.category = category
        self.inputs = inputs
        self.properties = properties
        self.hasOutput = hasOutput
    }
}

/// Registry of all available Elementary Audio node types
public final class NodeRegistry: @unchecked Sendable {
    public static let shared = NodeRegistry()

    private var descriptors: [String: NodeDescriptor] = [:]

    private init() {
        registerBuiltinNodes()
    }

    public func descriptor(for nodeType: String) -> NodeDescriptor? {
        descriptors[nodeType]
    }

    public func allDescriptors() -> [NodeDescriptor] {
        Array(descriptors.values).sorted { $0.displayName < $1.displayName }
    }

    public func descriptors(in category: NodeCategory) -> [NodeDescriptor] {
        descriptors.values
            .filter { $0.category == category }
            .sorted { $0.displayName < $1.displayName }
    }

    public func register(_ descriptor: NodeDescriptor) {
        descriptors[descriptor.nodeType] = descriptor
    }

    private func registerBuiltinNodes() {
        // MARK: - Oscillators
        register(NodeDescriptor(
            nodeType: "phasor",
            displayName: "Phasor",
            description: "Generates a ramp signal from 0 to 1 at the given rate. Useful for driving other oscillators or as a modulation source.",
            category: .oscillator,
            inputs: [PortDescriptor(id: "rate", name: "Rate", defaultValue: 440)]
        ))

        register(NodeDescriptor(
            nodeType: "cycle",
            displayName: "Sine",
            description: "Pure sine wave oscillator. The smoothest waveform with only a fundamental frequency.",
            category: .oscillator,
            inputs: [PortDescriptor(id: "freq", name: "Frequency", defaultValue: 440)]
        ))

        register(NodeDescriptor(
            nodeType: "blepsaw",
            displayName: "Saw",
            description: "Band-limited sawtooth wave. Rich in harmonics, good for bass and lead sounds.",
            category: .oscillator,
            inputs: [PortDescriptor(id: "freq", name: "Frequency", defaultValue: 440)]
        ))

        register(NodeDescriptor(
            nodeType: "blepsquare",
            displayName: "Square",
            description: "Band-limited square wave. Contains only odd harmonics, hollow sound.",
            category: .oscillator,
            inputs: [PortDescriptor(id: "freq", name: "Frequency", defaultValue: 440)]
        ))

        register(NodeDescriptor(
            nodeType: "bleptriangle",
            displayName: "Triangle",
            description: "Band-limited triangle wave. Softer than square, contains only odd harmonics.",
            category: .oscillator,
            inputs: [PortDescriptor(id: "freq", name: "Frequency", defaultValue: 440)]
        ))

        register(NodeDescriptor(
            nodeType: "noise",
            displayName: "Noise",
            description: "White noise generator. Random values at audio rate, useful for percussion and textures.",
            category: .oscillator
        ))

        // MARK: - Math (Binary)
        register(NodeDescriptor(
            nodeType: "add",
            displayName: "Add",
            description: "Adds two signals together. Use for mixing or combining modulation sources.",
            category: .math,
            inputs: [
                PortDescriptor(id: "a", name: "A", defaultValue: 0),
                PortDescriptor(id: "b", name: "B", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "sub",
            displayName: "Subtract",
            description: "Subtracts signal B from signal A. Useful for difference signals or inverting.",
            category: .math,
            inputs: [
                PortDescriptor(id: "a", name: "A", defaultValue: 0),
                PortDescriptor(id: "b", name: "B", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "mul",
            displayName: "Multiply",
            description: "Multiplies two signals. Essential for amplitude modulation and VCA behavior.",
            category: .math,
            inputs: [
                PortDescriptor(id: "a", name: "A", defaultValue: 1),
                PortDescriptor(id: "b", name: "B", defaultValue: 1)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "div",
            displayName: "Divide",
            description: "Divides signal A by signal B. Be careful of division by zero.",
            category: .math,
            inputs: [
                PortDescriptor(id: "a", name: "A", defaultValue: 1),
                PortDescriptor(id: "b", name: "B", defaultValue: 1)
            ]
        ))

        // MARK: - Math (Unary)
        register(NodeDescriptor(
            nodeType: "sin",
            displayName: "Sin",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "cos",
            displayName: "Cos",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "tan",
            displayName: "Tan",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "tanh",
            displayName: "Tanh",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "abs",
            displayName: "Abs",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "sqrt",
            displayName: "Sqrt",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 1)]
        ))

        register(NodeDescriptor(
            nodeType: "exp",
            displayName: "Exp",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "ln",
            displayName: "Ln",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 1)]
        ))

        register(NodeDescriptor(
            nodeType: "floor",
            displayName: "Floor",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "ceil",
            displayName: "Ceil",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "round",
            displayName: "Round",
            category: .math,
            inputs: [PortDescriptor(id: "x", name: "X", defaultValue: 0)]
        ))

        // MARK: - Filters
        register(NodeDescriptor(
            nodeType: "pole",
            displayName: "One-Pole",
            category: .filter,
            inputs: [
                PortDescriptor(id: "coef", name: "Coefficient", defaultValue: 0.9),
                PortDescriptor(id: "in", name: "Input", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "env",
            displayName: "Envelope",
            category: .filter,
            inputs: [
                PortDescriptor(id: "attack", name: "Attack", defaultValue: 0.01),
                PortDescriptor(id: "release", name: "Release", defaultValue: 0.1),
                PortDescriptor(id: "in", name: "Input", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "svf",
            displayName: "SVF",
            category: .filter,
            inputs: [
                PortDescriptor(id: "freq", name: "Frequency", defaultValue: 1000),
                PortDescriptor(id: "q", name: "Q", defaultValue: 1),
                PortDescriptor(id: "in", name: "Input", defaultValue: 0)
            ],
            properties: [
                PropertyDescriptor(id: "mode", name: "Mode", defaultValue: 0, range: 0...4)
            ]
        ))

        // MARK: - Delays
        register(NodeDescriptor(
            nodeType: "z",
            displayName: "Z-1",
            category: .delay,
            inputs: [PortDescriptor(id: "in", name: "Input", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "sdelay",
            displayName: "Sample Delay",
            category: .delay,
            inputs: [PortDescriptor(id: "in", name: "Input", defaultValue: 0)],
            properties: [
                PropertyDescriptor(id: "size", name: "Size", defaultValue: 512, range: 1...48000)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "delay",
            displayName: "Delay",
            category: .delay,
            inputs: [
                PortDescriptor(id: "time", name: "Time", defaultValue: 0.5),
                PortDescriptor(id: "in", name: "Input", defaultValue: 0)
            ],
            properties: [
                PropertyDescriptor(id: "size", name: "Max Size", defaultValue: 48000, range: 1...192000)
            ]
        ))

        // MARK: - Control
        register(NodeDescriptor(
            nodeType: "latch",
            displayName: "Latch",
            category: .control,
            inputs: [
                PortDescriptor(id: "trigger", name: "Trigger", defaultValue: 0),
                PortDescriptor(id: "in", name: "Input", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "counter",
            displayName: "Counter",
            category: .control,
            inputs: [PortDescriptor(id: "gate", name: "Gate", defaultValue: 0)]
        ))

        register(NodeDescriptor(
            nodeType: "seq",
            displayName: "Sequencer",
            category: .control,
            inputs: [PortDescriptor(id: "trigger", name: "Trigger", defaultValue: 0)],
            properties: [
                PropertyDescriptor(id: "hold", name: "Hold", defaultValue: 1, range: 0...1),
                PropertyDescriptor(id: "loop", name: "Loop", defaultValue: 1, range: 0...1)
            ]
        ))

        // MARK: - Analysis
        register(NodeDescriptor(
            nodeType: "meter",
            displayName: "Meter",
            category: .analysis,
            inputs: [PortDescriptor(id: "in", name: "Input", defaultValue: 0)],
            properties: [
                PropertyDescriptor(id: "name", name: "Name", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "scope",
            displayName: "Scope",
            category: .analysis,
            inputs: [PortDescriptor(id: "in", name: "Input", defaultValue: 0)],
            properties: [
                PropertyDescriptor(id: "name", name: "Name", defaultValue: 0),
                PropertyDescriptor(id: "size", name: "Size", defaultValue: 512, range: 64...4096)
            ]
        ))

        // MARK: - Feedback
        register(NodeDescriptor(
            nodeType: "tapIn",
            displayName: "Tap In",
            category: .feedback,
            inputs: [PortDescriptor(id: "in", name: "Input", defaultValue: 0)],
            properties: [
                PropertyDescriptor(id: "name", name: "Name", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "tapOut",
            displayName: "Tap Out",
            category: .feedback,
            properties: [
                PropertyDescriptor(id: "name", name: "Name", defaultValue: 0)
            ]
        ))

        // MARK: - Utility
        register(NodeDescriptor(
            nodeType: "const",
            displayName: "Constant",
            description: "Outputs a constant value. Use for fixed frequencies, gains, or parameters.",
            category: .utility,
            properties: [
                PropertyDescriptor(id: "value", name: "Value", defaultValue: 0)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "sr",
            displayName: "Sample Rate",
            description: "Outputs the current sample rate (e.g., 44100). Useful for time-based calculations.",
            category: .utility
        ))

        register(NodeDescriptor(
            nodeType: "in",
            displayName: "Audio Input",
            description: "Receives audio from an input channel. Connect to microphone or external audio.",
            category: .utility,
            properties: [
                PropertyDescriptor(id: "channel", name: "Channel", defaultValue: 0, range: 0...31)
            ]
        ))

        register(NodeDescriptor(
            nodeType: "out",
            displayName: "🔊 Output",
            description: "REQUIRED: Routes audio to the output. Every patch needs at least one output node to produce sound.",
            category: .utility,
            inputs: [PortDescriptor(id: "in", name: "Input", defaultValue: 0)],
            properties: [
                PropertyDescriptor(id: "channel", name: "Channel", defaultValue: 0, range: 0...31)
            ],
            hasOutput: false
        ))
    }
}
