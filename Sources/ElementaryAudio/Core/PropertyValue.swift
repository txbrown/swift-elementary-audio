import Foundation

/// A type-safe representation of audio node property values
///
/// `PropertyValue` bridges Swift types to the Elementary Audio runtime's
/// dynamic value system. It supports the common types used in audio DSP:
/// numbers, booleans, strings, arrays, and nested objects.
///
/// ## Example
/// ```swift
/// let frequency: PropertyValue = .number(440.0)
/// let notes: PropertyValue = .array([261.63, 293.66, 329.63])
/// let config: PropertyValue = .object(["attack": .number(0.01), "release": .number(0.5)])
/// ```
public enum PropertyValue: Sendable, Equatable {
    /// A floating-point number
    case number(Double)

    /// A boolean value
    case boolean(Bool)

    /// A string value
    case string(String)

    /// An array of numbers (for sequences, sample data, etc.)
    case array([Double])

    /// A nested dictionary of property values
    case object([String: PropertyValue])
}

// MARK: - ExpressibleBy Protocols

extension PropertyValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension PropertyValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension PropertyValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension PropertyValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PropertyValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Double...) {
        self = .array(elements)
    }
}

extension PropertyValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, PropertyValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Convenience Initializers

extension PropertyValue {
    /// Creates a number property from a Float
    public static func float(_ value: Float) -> PropertyValue {
        .number(Double(value))
    }

    /// Creates a number property from an Int
    public static func int(_ value: Int) -> PropertyValue {
        .number(Double(value))
    }

    /// Creates a number property from an Int32
    public static func int32(_ value: Int32) -> PropertyValue {
        .number(Double(value))
    }
}

// MARK: - Value Extraction

extension PropertyValue {
    /// Returns the number value if this is a `.number`, otherwise nil
    public var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    /// Returns the boolean value if this is a `.boolean`, otherwise nil
    public var boolValue: Bool? {
        guard case .boolean(let value) = self else { return nil }
        return value
    }

    /// Returns the string value if this is a `.string`, otherwise nil
    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    /// Returns the array value if this is a `.array`, otherwise nil
    public var arrayValue: [Double]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    /// Returns the object value if this is a `.object`, otherwise nil
    public var objectValue: [String: PropertyValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }
}
