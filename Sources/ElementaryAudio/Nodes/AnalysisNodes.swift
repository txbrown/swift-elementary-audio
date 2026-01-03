import Foundation

// MARK: - Meter

/// A level meter that reports the signal level via events
public struct MeterNode: AudioNode {
    public static let nodeType = "meter"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let name: String?

    public init(name: String? = nil, input: any AudioNode) {
        self.name = name
        self.children = [input]
        if let name = name {
            self.properties = ["name": .string(name)]
        } else {
            self.properties = [:]
        }
    }
}

// MARK: - Scope

/// An oscilloscope that captures signal data via events
public struct ScopeNode: AudioNode {
    public static let nodeType = "scope"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let name: String?
    public let size: Int

    public init(name: String? = nil, size: Int = 512, input: any AudioNode) {
        self.name = name
        self.size = size
        self.children = [input]

        var props: NodeProperties = ["size": .number(Double(size))]
        if let name = name {
            props["name"] = .string(name)
        }
        self.properties = props
    }
}

// MARK: - Snapshot

/// Captures a single sample value on trigger
public struct SnapshotNode: AudioNode {
    public static let nodeType = "snapshot"
    public let nodeId = NodeID()
    public let children: [any AudioNode]
    public let properties: NodeProperties

    public let name: String?

    public init(name: String? = nil, trigger: any AudioNode, input: any AudioNode) {
        self.name = name
        self.children = [trigger, input]
        if let name = name {
            self.properties = ["name": .string(name)]
        } else {
            self.properties = [:]
        }
    }
}
