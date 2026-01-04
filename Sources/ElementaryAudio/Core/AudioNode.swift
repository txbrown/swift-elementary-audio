import Foundation

/// The core protocol for all audio processing nodes
///
/// `AudioNode` represents a node in the audio processing graph. Nodes can
/// be composed together to create complex audio processing pipelines.
///
/// ## Implementing Custom Nodes
///
/// To create a custom node type, conform to this protocol:
///
/// ```swift
/// struct MySineNode: AudioNode {
///     static let nodeType = "sin"
///     let nodeId = NodeID()
///     let children: [any AudioNode]
///     let properties: NodeProperties
///
///     init(_ input: any AudioNode) {
///         self.children = [input]
///         self.properties = [:]
///     }
/// }
/// ```
public protocol AudioNode: Sendable {
    /// The Elementary Audio node type identifier (e.g., "sin", "mul", "phasor")
    static var nodeType: String { get }

    /// The node type identifier for this instance (may differ from static type for parameterized nodes)
    var nodeType: String { get }

    /// Unique identifier for this node instance
    var nodeId: NodeID { get }

    /// Child nodes that provide input signals to this node
    var children: [any AudioNode] { get }

    /// Configuration properties for this node
    var properties: NodeProperties { get }
}

// MARK: - Default Implementations

extension AudioNode {
    /// Default empty properties
    public var properties: NodeProperties { [:] }

    /// Default no children
    public var children: [any AudioNode] { [] }

    /// Default nodeType returns the static type
    public var nodeType: String { Self.nodeType }
}
