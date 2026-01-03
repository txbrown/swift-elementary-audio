import Foundation

// MARK: - Latch (Sample and Hold)

/// A sample-and-hold node
public struct LatchNode: AudioNode {
    public static let nodeType = "latch"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(trigger: any AudioNode, input: any AudioNode) {
        self.children = [trigger, input]
    }
}

// MARK: - Counter

/// A counter that increments on trigger
public struct CounterNode: AudioNode {
    public static let nodeType = "counter"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(gate: any AudioNode) {
        self.children = [gate]
    }
}

// MARK: - Accumulator

/// An accumulator that sums input values
public struct AccumNode: AudioNode {
    public static let nodeType = "accum"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(input: any AudioNode, reset: any AudioNode) {
        self.children = [input, reset]
    }
}

// MARK: - Sequence

/// A step sequencer
public struct SequenceNode: AudioNode {
    public static let nodeType = "seq"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let values: [Double]
    public let hold: Bool
    public let loop: Bool

    public init(trigger: any AudioNode, values: [Double], hold: Bool = true, loop: Bool = true) {
        self.values = values
        self.hold = hold
        self.loop = loop
        self.children = [trigger]
        self.properties = [
            "seq": .array(values),
            "hold": .boolean(hold),
            "loop": .boolean(loop)
        ]
    }
}
