import Foundation

/// Encodes Swift audio graph into instructions for the C++ runtime
///
/// The instruction encoder traverses the audio graph and generates a series
/// of instructions that the Elementary Audio runtime can execute to build
/// and update the processing graph.
public struct InstructionEncoder: Sendable {
    /// Instruction types matching the C++ runtime
    public enum InstructionType: Int32, Sendable {
        case createNode = 0
        case deleteNode = 1
        case appendChild = 2
        case setProperty = 3
        case activateRoots = 4
        case commitUpdates = 5
    }

    /// A single instruction for the runtime
    public struct Instruction: Sendable {
        public let type: InstructionType
        public let nodeId: NodeID?
        public let nodeType: String?
        public let propertyKey: String?
        public let propertyValue: PropertyValue?
        public let childId: NodeID?
        public let rootIds: [NodeID]?

        init(type: InstructionType,
             nodeId: NodeID? = nil,
             nodeType: String? = nil,
             propertyKey: String? = nil,
             propertyValue: PropertyValue? = nil,
             childId: NodeID? = nil,
             rootIds: [NodeID]? = nil) {
            self.type = type
            self.nodeId = nodeId
            self.nodeType = nodeType
            self.propertyKey = propertyKey
            self.propertyValue = propertyValue
            self.childId = childId
            self.rootIds = rootIds
        }
    }

    private var instructions: [Instruction] = []
    private var encodedNodes: Set<Int32> = []

    /// Creates a new instruction encoder
    public init() {}

    // MARK: - Encoding Methods

    /// Encodes a complete audio graph
    ///
    /// - Parameter graph: The audio graph to encode
    public mutating func encode(_ graph: AudioGraph) {
        // Encode all root nodes recursively
        for root in graph.roots {
            encodeNode(root)
        }

        // Activate the root nodes
        let rootIds = graph.roots.map { $0.nodeId }
        activateRoots(rootIds)

        // Commit the updates
        commit()
    }

    /// Encodes a single node and its children recursively
    private mutating func encodeNode(_ node: any AudioNode) {
        // Unwrap Signal to get the actual node
        let actualNode: any AudioNode
        let actualNodeType: String

        if let signal = node as? Signal {
            actualNode = signal.underlyingNode
            actualNodeType = signal.wrappedNodeType
        } else {
            actualNode = node
            actualNodeType = node.nodeType
        }

        // Skip if already encoded
        guard !encodedNodes.contains(actualNode.nodeId.rawValue) else { return }
        encodedNodes.insert(actualNode.nodeId.rawValue)

        // First encode all children
        for child in actualNode.children {
            encodeNode(child)
        }

        // Create this node
        createNode(id: actualNode.nodeId, type: actualNodeType)

        // Set properties
        for (key, value) in actualNode.properties {
            setProperty(nodeId: actualNode.nodeId, key: key, value: value)
        }

        // Append children
        for child in actualNode.children {
            appendChild(parentId: actualNode.nodeId, childId: child.nodeId)
        }
    }

    // MARK: - Instruction Generation

    /// Creates a node with the given type
    public mutating func createNode(id: NodeID, type: String) {
        instructions.append(Instruction(
            type: .createNode,
            nodeId: id,
            nodeType: type
        ))
    }

    /// Deletes a node
    public mutating func deleteNode(id: NodeID) {
        instructions.append(Instruction(
            type: .deleteNode,
            nodeId: id
        ))
    }

    /// Appends a child node to a parent
    public mutating func appendChild(parentId: NodeID, childId: NodeID) {
        instructions.append(Instruction(
            type: .appendChild,
            nodeId: parentId,
            childId: childId
        ))
    }

    /// Sets a property on a node
    public mutating func setProperty(nodeId: NodeID, key: String, value: PropertyValue) {
        instructions.append(Instruction(
            type: .setProperty,
            nodeId: nodeId,
            propertyKey: key,
            propertyValue: value
        ))
    }

    /// Activates the specified root nodes for output
    public mutating func activateRoots(_ rootIds: [NodeID]) {
        instructions.append(Instruction(
            type: .activateRoots,
            rootIds: rootIds
        ))
    }

    /// Commits all pending updates
    public mutating func commit() {
        instructions.append(Instruction(type: .commitUpdates))
    }

    // MARK: - Output

    /// Returns all generated instructions
    public var allInstructions: [Instruction] { instructions }

    /// The number of instructions generated
    public var count: Int { instructions.count }

    /// Clears all instructions
    public mutating func clear() {
        instructions.removeAll()
        encodedNodes.removeAll()
    }
}

// MARK: - Debug Description

extension InstructionEncoder.Instruction: CustomStringConvertible {
    public var description: String {
        switch type {
        case .createNode:
            return "CREATE(\(nodeId?.rawValue ?? -1), \(nodeType ?? "?"))"
        case .deleteNode:
            return "DELETE(\(nodeId?.rawValue ?? -1))"
        case .appendChild:
            return "APPEND(\(nodeId?.rawValue ?? -1), \(childId?.rawValue ?? -1))"
        case .setProperty:
            return "SET(\(nodeId?.rawValue ?? -1), \(propertyKey ?? "?"), \(propertyValue.map { "\($0)" } ?? "?"))"
        case .activateRoots:
            let ids = rootIds?.map { "\($0.rawValue)" }.joined(separator: ", ") ?? ""
            return "ACTIVATE([\(ids)])"
        case .commitUpdates:
            return "COMMIT"
        }
    }
}

extension InstructionEncoder: CustomStringConvertible {
    public var description: String {
        instructions.map { $0.description }.joined(separator: "\n")
    }
}
