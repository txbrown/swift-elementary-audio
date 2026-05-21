import Foundation

// MARK: - Seq2 (Step Sequencer)

/// A step sequencer with keyed identity for stable graph updates.
///
/// `seq2` steps through a pattern of values on each trigger pulse.
/// The `key` is stored in the node's properties so the Elementary runtime
/// can match this node across successive graph renders, preserving the counter
/// position. Property updates use `GraphRenderer.setProperty(nodeId:key:value:)`
/// where `nodeId` is this node's identifier.
///
/// Mirrors the RN `el.seq2({ key, seq, hold, loop }, trigger, gate)`.
public struct Seq2Node: AudioNode {
    public static let nodeType = "seq2"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public init(key: String, seq: [Double], hold: Bool = true, loop: Bool = true, trigger: any AudioNode, gate: any AudioNode) {
        children = [trigger, gate]
        properties = [
            "key": .string(key),
            "seq": .array(seq),
            "hold": .boolean(hold),
            "loop": .boolean(loop)
        ]
    }
}

// MARK: - SyncPhasor

/// A phasor that resets to 0 on the rising edge of a gate signal.
///
/// Ramps from 0–1 at the given frequency, resetting to 0 on the rising
/// edge of the gate signal. Used for transport clock synchronization.
public struct SyncPhasorNode: AudioNode {
    // Swift DSL uses `syncphasor` to match the RN API;
    // the runtime node type is `sphasor`.
    public static let nodeType = "sphasor"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(frequency: any AudioNode, reset: any AudioNode) {
        children = [frequency, reset]
    }
}

// MARK: - Sample Playback

/// A sample playback node that reads from the VFS.
///
/// Modes:
/// - `"trigger"`: Plays the full sample on rising edge (drums, one-shots)
/// - `"gate"`: Sustains while gate is high (melodic, piano)
public struct SampleNode: AudioNode {
    public static let nodeType = "sample"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public init(path: String, mode: String = "trigger", key: String? = nil, trigger: any AudioNode, rate: any AudioNode) {
        children = [trigger, rate]
        var props: NodeProperties = [
            "path": .string(path),
            "mode": .string(mode)
        ]
        if let key {
            props["key"] = .string(key)
        }
        properties = props
    }
}

// MARK: - Multiply (El.mul)

/// Element-wise multiplication of two signals.
///
/// While the `*` operator handles multiply on `Signal`,
/// `El.mul` provides the explicit DSP graph node.
/// Pass an optional `key` to give the node a stable identity across graph
/// renders; property updates still require the node's `nodeId`.
public struct MulNode: AudioNode {
    public static let nodeType = "mul"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public init(_ a: any AudioNode, _ b: any AudioNode, key: String? = nil) {
        children = [a, b]
        var props: NodeProperties = [:]
        if let key {
            props["key"] = .string(key)
        }
        properties = props
    }
}

// MARK: - Const with key

/// A constant node with a stable identity for in-place graph updates.
///
/// The `key` is stored in the node's properties so the Elementary runtime can
/// match this node across successive graph renders. To change the value at
/// runtime, call `GraphRenderer.setProperty(nodeId:key:value:)` where
/// `nodeId` is this node's identifier and `key` is `"value"`.
public struct KeyedConstNode: AudioNode {
    public static let nodeType = "const"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties

    public init(key: String, value: Double) {
        properties = [
            "key": .string(key),
            "value": .number(value)
        ]
    }
}
