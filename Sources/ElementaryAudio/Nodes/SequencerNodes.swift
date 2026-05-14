import Foundation

// MARK: - Seq2 (Step Seql2 — the core sequencing primitive)

/// A step sequencer with keyed identity for in-place updates.
///
/// `seq2` is the primary sequencing node in Elementary. It steps through
/// a pattern of values on each trigger pulse, optionally holding and looping.
/// The `key` prop ensures that property updates (via setProperty) don't
/// reset the counter position.
///
/// This mirrors the RN app's `el.seq2({ key, seq, hold, loop }, trigger, gate)`
public struct Seq2Node: AudioNode {
    public static let nodeType = "seq2"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public init(key: String, seq: [Double], hold: Bool = true, loop: Bool = true, trigger: any AudioNode, gate: any AudioNode) {
        self.children = [trigger, gate]
        self.properties = [
            "key": .string(key),
            "seq": .array(seq),
            "hold": .boolean(hold),
            "loop": .boolean(loop),
        ]
    }
}

// MARK: - SyncPhasor

/// A phasor that resets to 0 on the rising edge of a gate signal.
///
/// `syncphasor` is used for transport clock synchronization: it ramps from
/// 0–1 at the given frequency, but resets to 0 when the gate transitions
/// from 0 to 1, ensuring that playback always starts from the beginning.
public struct SyncPhasorNode: AudioNode {
    public static let nodeType = "syncphasor"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties = [:]

    public init(frequency: any AudioNode, reset: any AudioNode) {
        self.children = [frequency, reset]
    }
}

// MARK: - Sample Playback

/// A sample playback node that reads from the VFS.
///
/// Supports two modes:
/// - `"trigger"`: Plays the full sample when the trigger input goes high (drums, one-shots)
/// - `"gate"`: Sustains while the gate is high with pitch control via rate (melodic, piano)
///
/// This mirrors the RN app's `el.sample({ path, mode, key }, trigger, rate)`
public struct SampleNode: AudioNode {
    public static let nodeType = "sample"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public init(path: String, mode: String = "trigger", key: String? = nil, trigger: any AudioNode, rate: any AudioNode) {
        self.children = [trigger, rate]
        var props: NodeProperties = [
            "path": .string(path),
            "mode": .string(mode),
        ]
        if let key = key {
            props["key"] = .string(key)
        }
        self.properties = props
    }
}

// MARK: - Multiply (El.mul)

/// Element-wise multiplication of two signals.
///
/// While the `*` operator already handles multiply on `Signal`,
/// `El.mul` provides the explicit DSP graph node for when you need
/// a keyed multiply that can be updated via setProperty.
public struct MulNode: AudioNode {
    public static let nodeType = "mul"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public init(_ a: any AudioNode, _ b: any AudioNode, key: String? = nil) {
        self.children = [a, b]
        var props: NodeProperties = [:]
        if let key = key {
            props["key"] = .string(key)
        }
        self.properties = props
    }
}

// MARK: - Const with key

/// A constant node with a key property for setProperty updates.
///
/// This is essential for live parameter changes (tempo, mute, etc.)
/// without rebuilding the entire graph. The key allows setProperty
/// to target this specific node.
public struct KeyedConstNode: AudioNode {
    public static let nodeType = "const"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties

    public init(key: String, value: Double) {
        self.properties = [
            "key": .string(key),
            "value": .number(value),
        ]
    }
}