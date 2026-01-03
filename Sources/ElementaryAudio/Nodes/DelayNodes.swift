import Foundation

// MARK: - Single Sample Delay

/// A single-sample delay (z^-1)
public struct SingleSampleDelayNode: AudioNode {
    public static let nodeType = "z"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(input: any AudioNode) {
        self.children = [input]
    }
}

// MARK: - Sample Delay

/// A fixed-length sample delay
public struct SampleDelayNode: AudioNode {
    public static let nodeType = "sdelay"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let size: Int

    public init(size: Int, input: any AudioNode) {
        self.size = size
        self.children = [input]
        self.properties = ["size": .number(Double(size))]
    }
}

// MARK: - Variable Delay

/// A variable-length delay line
public struct DelayNode: AudioNode {
    public static let nodeType = "delay"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let size: Int

    public init(size: Int, time: any AudioNode, input: any AudioNode) {
        self.size = size
        self.children = [time, input]
        self.properties = ["size": .number(Double(size))]
    }
}
