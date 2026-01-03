import Foundation

// MARK: - Unary Math Operations

/// A node that applies a unary math function to its input
public struct UnaryMathNode: AudioNode {
    public static var nodeType: String { "unary" }

    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties
    public let operation: Operation

    /// Unary math operations
    public enum Operation: String, Sendable {
        case sin, cos, tan, tanh
        case asinh, acosh, atanh
        case asin, acos, atan
        case sinh, cosh
        case ln, log, log2
        case ceil, floor, round
        case sqrt, exp, abs
    }

    /// The actual Elementary node type
    public var nodeType: String { operation.rawValue }

    public init(_ operation: Operation, _ input: any AudioNode) {
        self.operation = operation
        self.children = [input]
        self.properties = [:]
    }
}

// MARK: - Sample Rate Node

/// A node that outputs the current sample rate
public struct SampleRateNode: AudioNode {
    public static let nodeType = "sr"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties = [:]

    public init() {}
}

// MARK: - Input Node

/// A node that reads from an input channel
public struct InputNode: AudioNode {
    public static let nodeType = "in"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties

    /// The input channel index
    public let channel: Int

    public init(channel: Int = 0) {
        self.channel = channel
        self.properties = ["channel": .number(Double(channel))]
    }
}
