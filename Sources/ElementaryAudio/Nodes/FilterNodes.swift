import Foundation

// MARK: - One Pole Filter

/// A simple one-pole lowpass filter
public struct OnePoleNode: AudioNode {
    public static let nodeType = "pole"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(coefficient: any AudioNode, input: any AudioNode) {
        self.children = [coefficient, input]
    }
}

// MARK: - Envelope Follower

/// An envelope follower with separate attack and release times
public struct EnvelopeNode: AudioNode {
    public static let nodeType = "env"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(attack: any AudioNode, release: any AudioNode, input: any AudioNode) {
        self.children = [attack, release, input]
    }
}

// MARK: - State Variable Filter

/// A state variable filter with multiple modes
public struct SVFNode: AudioNode {
    public static let nodeType = "svf"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let mode: El.SVFMode

    public init(mode: El.SVFMode, frequency: any AudioNode, q: any AudioNode, input: any AudioNode) {
        self.mode = mode
        self.children = [frequency, q, input]
        self.properties = ["mode": .string(mode.rawValue)]
    }
}

// MARK: - Biquad Filter

/// A biquad filter (transposed direct form II)
public struct BiquadNode: AudioNode {
    public static let nodeType = "biquad"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(
        b0: any AudioNode,
        b1: any AudioNode,
        b2: any AudioNode,
        a1: any AudioNode,
        a2: any AudioNode,
        input: any AudioNode
    ) {
        self.children = [b0, b1, b2, a1, a2, input]
    }
}
