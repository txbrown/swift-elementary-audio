import Foundation

// MARK: - Tap In

/// Creates a feedback tap input point
///
/// Use with `TapOutNode` to create feedback loops in the audio graph.
/// The signal from `tapIn` will be available at the corresponding `tapOut`
/// delayed by one processing block.
public struct TapInNode: AudioNode {
    public static let nodeType = "tapIn"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let name: String

    public init(name: String, input: any AudioNode) {
        self.name = name
        self.children = [input]
        self.properties = ["name": .string(name)]
    }
}

// MARK: - Tap Out

/// Reads from a feedback tap point
///
/// Use with `TapInNode` to create feedback loops. The output is the
/// signal from the corresponding `tapIn`, delayed by one processing block.
///
/// ## Example
/// ```swift
/// let input = El.cycle(440) * 0.3
/// let feedback = El.tapOut("fb")
/// let mixed = input + feedback * 0.5
/// let delayed = El.sdelay(22050, mixed)
/// let output = El.tapIn("fb", delayed)
/// ```
public struct TapOutNode: AudioNode {
    public static let nodeType = "tapOut"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties

    public let name: String

    public init(name: String) {
        self.name = name
        self.properties = ["name": .string(name)]
    }
}
