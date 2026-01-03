import Foundation

/// Thread-safe atomic counter for generating unique node IDs
final class NodeIDGenerator: @unchecked Sendable {
    private var counter: Int32 = 0
    private let lock = NSLock()

    static let shared = NodeIDGenerator()

    private init() {}

    func next() -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return counter
    }
}

/// Type-safe, globally unique identifier for audio nodes
///
/// Each `NodeID` is guaranteed to be unique within the current process.
/// IDs are generated using an atomic counter, making them safe to create
/// from any thread.
///
/// ## Example
/// ```swift
/// let node1 = NodeID()
/// let node2 = NodeID()
/// assert(node1 != node2)
/// ```
public struct NodeID: Hashable, Sendable, CustomStringConvertible {
    /// The underlying integer identifier
    public let rawValue: Int32

    /// Creates a new unique node ID
    public init() {
        self.rawValue = NodeIDGenerator.shared.next()
    }

    /// Creates a NodeID from a raw value (for internal use)
    internal init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public var description: String {
        "NodeID(\(rawValue))"
    }
}
