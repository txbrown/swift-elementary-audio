import Foundation

// MARK: - Phasor

/// A phasor (ramp) oscillator that outputs values from 0 to 1
public struct PhasorNode: AudioNode {
    public static let nodeType = "phasor"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(frequency: any AudioNode) {
        self.children = [frequency]
    }
}

// MARK: - PolyBLEP Oscillators

/// A PolyBLEP sawtooth oscillator
public struct BlepSawNode: AudioNode {
    public static let nodeType = "blepsaw"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(frequency: any AudioNode) {
        self.children = [frequency]
    }
}

/// A PolyBLEP square wave oscillator
public struct BlepSquareNode: AudioNode {
    public static let nodeType = "blepsquare"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(frequency: any AudioNode) {
        self.children = [frequency]
    }
}

/// A PolyBLEP triangle wave oscillator
public struct BlepTriangleNode: AudioNode {
    public static let nodeType = "bleptriangle"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(frequency: any AudioNode) {
        self.children = [frequency]
    }
}

// MARK: - Noise

/// A white noise generator
public struct NoiseNode: AudioNode {
    // Elementary runtime exposes white noise as `rand`.
    // Keep `El.noise()` as the Swift/RN-compatible DSL spelling.
    public static let nodeType = "rand"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties = [:]

    public init() {}
}
