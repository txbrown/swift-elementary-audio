import Foundation

/// Represents a complete audio processing graph ready for rendering
///
/// An `AudioGraph` contains one or more root nodes that produce the final
/// audio output. Each root corresponds to an output channel.
///
/// ## Example
/// ```swift
/// let graph = AudioGraph(roots: [
///     leftChannelNode,   // Channel 0
///     rightChannelNode   // Channel 1
/// ])
/// ```
public struct AudioGraph: Sendable {
    /// The root nodes of the graph, one per output channel
    public let roots: [any AudioNode]

    /// The number of output channels
    public var channelCount: Int { roots.count }

    /// Creates an audio graph with the given root nodes
    ///
    /// - Parameter roots: The root nodes, one per output channel
    public init(roots: [any AudioNode]) {
        self.roots = roots
    }

    /// Creates a mono audio graph with a single root node
    ///
    /// - Parameter root: The single root node for mono output
    public init(root: any AudioNode) {
        self.roots = [root]
    }

    /// Creates a stereo audio graph with left and right channels
    ///
    /// - Parameters:
    ///   - left: The left channel root node
    ///   - right: The right channel root node
    public init(left: any AudioNode, right: any AudioNode) {
        self.roots = [left, right]
    }
}

// MARK: - Root Node Wrapper

/// A special node that marks an output channel root
///
/// Root nodes are automatically created by the `AudioGraphBuilder`
/// to wrap the final output nodes for each channel.
public struct RootNode: AudioNode {
    public static let nodeType = "root"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    /// The output channel index (0 = left/mono, 1 = right, etc.)
    public let channel: Int

    /// Creates a root node for the specified channel
    ///
    /// - Parameters:
    ///   - channel: The output channel index
    ///   - child: The node that produces this channel's output
    public init(channel: Int, child: any AudioNode) {
        self.channel = channel
        self.children = [child]
        self.properties = ["channel": .number(Double(channel))]
    }
}
