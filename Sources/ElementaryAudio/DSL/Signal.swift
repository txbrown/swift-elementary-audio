import Foundation

/// A wrapper type that represents an audio signal in the DSL
///
/// `Signal` is the primary type used when building audio graphs with the
/// declarative DSL. It wraps any `AudioNode` and provides operator overloads
/// and method chaining for ergonomic graph composition.
///
/// ## Creating Signals
///
/// Signals are typically created using the `El` namespace:
/// ```swift
/// let sine = El.cycle(440)    // 440Hz sine wave
/// let saw = El.blepsaw(220)   // 220Hz sawtooth
/// ```
///
/// ## Combining Signals
///
/// Use operators to combine signals:
/// ```swift
/// let mixed = sine * 0.5 + saw * 0.3
/// let modulated = El.cycle(440 + lfo * 100)
/// ```
///
/// ## Literal Conversion
///
/// Numbers are automatically converted to constant signals:
/// ```swift
/// let attenuated = sine * 0.5  // 0.5 becomes a constant signal
/// ```
public struct Signal: AudioNode, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    private let wrapped: any AudioNode

    // MARK: - AudioNode Conformance

    public static let nodeType = "signal"

    public var nodeId: NodeID { wrapped.nodeId }

    public var children: [any AudioNode] { wrapped.children }

    public var properties: NodeProperties { wrapped.properties }

    /// The actual node type of the wrapped node
    public var wrappedNodeType: String { wrapped.nodeType }

    // MARK: - Initialization

    /// Wraps an existing audio node in a Signal
    public init(_ node: any AudioNode) {
        self.wrapped = node
    }

    /// Creates a constant signal from a Double
    public init(floatLiteral value: Double) {
        self.wrapped = ConstNode(value)
    }

    /// Creates a constant signal from an Int
    public init(integerLiteral value: Int) {
        self.wrapped = ConstNode(Double(value))
    }

    /// Creates a constant signal from any numeric value
    public init<T: BinaryFloatingPoint>(_ value: T) {
        self.wrapped = ConstNode(Double(value))
    }

    /// Creates a constant signal from any integer value
    public init<T: BinaryInteger>(_ value: T) {
        self.wrapped = ConstNode(Double(value))
    }

    // MARK: - Internal Access

    /// Access the underlying node (for encoding)
    internal var underlyingNode: any AudioNode { wrapped }
}

// MARK: - Constant Node

/// A node that outputs a constant value
public struct ConstNode: AudioNode {
    public static let nodeType = "const"
    public let nodeId = NodeID()
    public let children: [any AudioNode] = []
    public let properties: NodeProperties

    /// The constant value this node outputs
    public let value: Double

    /// Creates a constant node with the given value
    public init(_ value: Double) {
        self.value = value
        self.properties = ["value": .number(value)]
    }
}
