import Foundation

/// A container for audio node properties with type-safe access
///
/// `NodeProperties` provides a dictionary-like interface for storing
/// and accessing property values on audio nodes.
///
/// ## Example
/// ```swift
/// var props: NodeProperties = [
///     "frequency": 440.0,
///     "gain": 0.5
/// ]
/// props["attack"] = 0.01
/// ```
public struct NodeProperties: Sendable, Equatable {
    private var storage: [String: PropertyValue]

    /// Creates an empty properties container
    public init() {
        self.storage = [:]
    }

    /// Creates a properties container from a dictionary
    public init(_ dictionary: [String: PropertyValue]) {
        self.storage = dictionary
    }

    /// Access a property value by key
    public subscript(key: String) -> PropertyValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    /// The number of properties
    public var count: Int { storage.count }

    /// Whether the container is empty
    public var isEmpty: Bool { storage.isEmpty }

    /// All property keys
    public var keys: Dictionary<String, PropertyValue>.Keys {
        storage.keys
    }

    /// All property values
    public var values: Dictionary<String, PropertyValue>.Values {
        storage.values
    }

    /// Iterate over key-value pairs
    public func forEach(_ body: (String, PropertyValue) throws -> Void) rethrows {
        try storage.forEach { try body($0.key, $0.value) }
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension NodeProperties: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, PropertyValue)...) {
        self.storage = Dictionary(uniqueKeysWithValues: elements)
    }
}

// MARK: - Sequence Conformance

extension NodeProperties: Sequence {
    public func makeIterator() -> Dictionary<String, PropertyValue>.Iterator {
        storage.makeIterator()
    }
}
