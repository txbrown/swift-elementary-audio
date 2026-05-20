//
//  AudioGraph+Traversal.swift
//  ElementaryAudio
//
//  Tree-walking helpers for inspecting audio graphs in tests and tooling.
//  All operations are pure — no rendering or runtime required.
//

// MARK: - AudioGraph traversal

public extension AudioGraph {
    /// Returns the first node whose "key" property equals `key`.
    /// Matches `KeyedConstNode` and `Seq2Node` keyed entries.
    func findNode(key: String) -> (any AudioNode)? {
        roots.lazy.compactMap { $0.findNode(key: key) }.first
    }

    /// Returns the first node whose `nodeType` matches `type`.
    func findNode(ofType type: String) -> (any AudioNode)? {
        roots.lazy.compactMap { $0.findNode(ofType: type) }.first
    }

    /// Returns all nodes whose `nodeType` matches `type`.
    func collectNodes(ofType type: String) -> [any AudioNode] {
        roots.flatMap { $0.collectNodes(ofType: type) }
    }

    /// Returns all nodes whose "key" property equals `key`.
    func collectNodes(key: String) -> [any AudioNode] {
        roots.flatMap { $0.collectNodes(key: key) }
    }

    /// Shortcut: returns the `value` property of the first node keyed by `key`.
    /// Useful for asserting `El.const(key:value:)` parameter values.
    func constValue(key: String) -> Double? {
        findNode(key: key).flatMap { $0.properties["value"]?.numberValue }
    }

    /// Returns the sequence array of the first `seq2` node keyed by `key`.
    func seq2Pattern(key: String) -> [Double]? {
        findNode(key: key).flatMap { $0.properties["seq"]?.arrayValue }
    }
}

// MARK: - AudioNode traversal

public extension AudioNode {
    func findNode(key: String) -> (any AudioNode)? {
        if properties["key"] == .string(key) { return self }
        return children.lazy.compactMap { $0.findNode(key: key) }.first
    }

    func findNode(ofType type: String) -> (any AudioNode)? {
        if nodeType == type { return self }
        return children.lazy.compactMap { $0.findNode(ofType: type) }.first
    }

    func collectNodes(ofType type: String) -> [any AudioNode] {
        let own: [any AudioNode] = nodeType == type ? [self] : []
        return own + children.flatMap { $0.collectNodes(ofType: type) }
    }

    func collectNodes(key: String) -> [any AudioNode] {
        let own: [any AudioNode] = (properties["key"] == .string(key)) ? [self] : []
        return own + children.flatMap { $0.collectNodes(key: key) }
    }
}
