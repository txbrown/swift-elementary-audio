import Foundation

// MARK: - Arithmetic Operators

/// Addition of two signals
public func + (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.add, lhs, rhs))
}

public func + (lhs: Signal, rhs: Double) -> Signal {
    lhs + Signal(rhs)
}

public func + (lhs: Double, rhs: Signal) -> Signal {
    Signal(lhs) + rhs
}

public func + (lhs: Signal, rhs: Int) -> Signal {
    lhs + Signal(Double(rhs))
}

public func + (lhs: Int, rhs: Signal) -> Signal {
    Signal(Double(lhs)) + rhs
}

/// Subtraction of two signals
public func - (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.sub, lhs, rhs))
}

public func - (lhs: Signal, rhs: Double) -> Signal {
    lhs - Signal(rhs)
}

public func - (lhs: Double, rhs: Signal) -> Signal {
    Signal(lhs) - rhs
}

/// Negation of a signal
public prefix func - (signal: Signal) -> Signal {
    Signal(0.0) - signal
}

/// Multiplication of two signals
public func * (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.mul, lhs, rhs))
}

public func * (lhs: Signal, rhs: Double) -> Signal {
    lhs * Signal(rhs)
}

public func * (lhs: Double, rhs: Signal) -> Signal {
    Signal(lhs) * rhs
}

public func * (lhs: Signal, rhs: Int) -> Signal {
    lhs * Signal(Double(rhs))
}

public func * (lhs: Int, rhs: Signal) -> Signal {
    Signal(Double(lhs)) * rhs
}

/// Division of two signals
public func / (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.div, lhs, rhs))
}

public func / (lhs: Signal, rhs: Double) -> Signal {
    lhs / Signal(rhs)
}

public func / (lhs: Double, rhs: Signal) -> Signal {
    Signal(lhs) / rhs
}

/// Modulo of two signals
public func % (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.mod, lhs, rhs))
}

// MARK: - Comparison Operators

/// Less than comparison
public func < (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.lt, lhs, rhs))
}

public func < (lhs: Signal, rhs: Double) -> Signal {
    lhs < Signal(rhs)
}

/// Less than or equal comparison
public func <= (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.leq, lhs, rhs))
}

public func <= (lhs: Signal, rhs: Double) -> Signal {
    lhs <= Signal(rhs)
}

/// Greater than comparison
public func > (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.gt, lhs, rhs))
}

public func > (lhs: Signal, rhs: Double) -> Signal {
    lhs > Signal(rhs)
}

/// Greater than or equal comparison
public func >= (lhs: Signal, rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.geq, lhs, rhs))
}

public func >= (lhs: Signal, rhs: Double) -> Signal {
    lhs >= Signal(rhs)
}

// MARK: - Binary Math Node

/// A node that performs binary math operations
public struct BinaryMathNode: AudioNode {
    public static var nodeType: String { "binary" }

    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    /// The operation this node performs
    public let operation: Operation

    /// Binary math operations
    public enum Operation: String, Sendable {
        case add, sub, mul, div, mod
        case min, max, pow
        case lt = "le"      // less than
        case leq            // less than or equal
        case gt = "ge"      // greater than
        case geq            // greater than or equal
        case eq             // equal
        case and, or
    }

    /// The actual node type based on operation
    public var nodeType: String { operation.rawValue }

    /// Creates a binary math node
    public init(_ operation: Operation, _ lhs: any AudioNode, _ rhs: any AudioNode) {
        self.operation = operation
        self.children = [lhs, rhs]
        self.properties = [:]
    }
}

// MARK: - Variadic Math Operations

/// Add multiple signals together
public func add(_ signals: Signal...) -> Signal {
    guard let first = signals.first else {
        return Signal(0.0)
    }
    return signals.dropFirst().reduce(first) { $0 + $1 }
}

/// Multiply multiple signals together
public func mul(_ signals: Signal...) -> Signal {
    guard let first = signals.first else {
        return Signal(1.0)
    }
    return signals.dropFirst().reduce(first) { $0 * $1 }
}

/// Returns the minimum of two signals
public func min(_ lhs: Signal, _ rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.min, lhs, rhs))
}

/// Returns the maximum of two signals
public func max(_ lhs: Signal, _ rhs: Signal) -> Signal {
    Signal(BinaryMathNode(.max, lhs, rhs))
}

/// Raises lhs to the power of rhs
public func pow(_ base: Signal, _ exponent: Signal) -> Signal {
    Signal(BinaryMathNode(.pow, base, exponent))
}

public func pow(_ base: Signal, _ exponent: Double) -> Signal {
    pow(base, Signal(exponent))
}
