@preconcurrency import Flow
import SwiftUI

/// Creates Flow-compatible nodes from Elementary node descriptors
public struct FlowNodeAdapter {

    /// Create a Flow Node from an Elementary node descriptor
    public static func createFlowNode(
        from descriptor: NodeDescriptor,
        at position: CGPoint = .zero
    ) -> Node {
        // Build input ports
        let inputs: [Flow.Port] = descriptor.inputs.map { port in
            Flow.Port(name: port.name)
        }

        // Single output port for signal
        let outputs: [Flow.Port] = descriptor.hasOutput ? [Flow.Port(name: "Out")] : []

        return Node(
            name: descriptor.displayName,
            position: position,
            inputs: inputs,
            outputs: outputs
        )
    }

    /// Create a Flow Node with a specific title (for duplicate nodes)
    public static func createFlowNode(
        from descriptor: NodeDescriptor,
        title: String,
        at position: CGPoint = .zero
    ) -> Node {
        let inputs: [Flow.Port] = descriptor.inputs.map { port in
            Flow.Port(name: port.name)
        }

        let outputs: [Flow.Port] = descriptor.hasOutput ? [Flow.Port(name: "Out")] : []

        return Node(
            name: title,
            position: position,
            inputs: inputs,
            outputs: outputs
        )
    }
}

/// Extended node data stored alongside Flow nodes
public struct ElementaryNodeData: Identifiable, Codable, Sendable {
    public let id: UUID
    public let nodeType: String
    public var propertyValues: [String: Double]

    public init(nodeType: String, propertyValues: [String: Double] = [:]) {
        self.id = UUID()
        self.nodeType = nodeType
        self.propertyValues = propertyValues
    }

    public init(from descriptor: NodeDescriptor) {
        self.id = UUID()
        self.nodeType = descriptor.nodeType
        self.propertyValues = Dictionary(
            uniqueKeysWithValues: descriptor.properties.map { ($0.id, $0.defaultValue) }
        )
    }
}

/// A complete Elementary Flow patch with nodes and their metadata
public struct ElementaryPatch {
    public var flowPatch: Patch
    public var nodeData: [Int: ElementaryNodeData]  // Flow node index -> Elementary data

    public init() {
        self.flowPatch = Patch(nodes: [], wires: [])
        self.nodeData = [:]
    }

    public init(flowPatch: Patch, nodeData: [Int: ElementaryNodeData]) {
        self.flowPatch = flowPatch
        self.nodeData = nodeData
    }

    /// Add a node to the patch
    public mutating func addNode(
        descriptor: NodeDescriptor,
        at position: CGPoint = .zero
    ) -> Int {
        let flowNode = FlowNodeAdapter.createFlowNode(from: descriptor, at: position)
        let data = ElementaryNodeData(from: descriptor)

        // Mutate directly to preserve Flow's binding behavior
        flowPatch.nodes.append(flowNode)

        let index = flowPatch.nodes.count - 1
        nodeData[index] = data

        return index
    }

    /// Connect two nodes
    public mutating func connect(
        from outputNodeIndex: Int,
        outputPort: Int = 0,
        to inputNodeIndex: Int,
        inputPort: Int
    ) {
        let wire = Wire(
            from: OutputID(outputNodeIndex, outputPort),
            to: InputID(inputNodeIndex, inputPort)
        )

        // Mutate directly to preserve Flow's binding behavior
        flowPatch.wires.insert(wire)
    }

    /// Remove a node and its connections
    public mutating func removeNode(at index: Int) {
        guard index < flowPatch.nodes.count else { return }

        // Remove node directly
        flowPatch.nodes.remove(at: index)
        nodeData.removeValue(forKey: index)

        // Re-index remaining node data
        var newNodeData: [Int: ElementaryNodeData] = [:]
        for (oldIndex, data) in nodeData {
            if oldIndex > index {
                newNodeData[oldIndex - 1] = data
            } else {
                newNodeData[oldIndex] = data
            }
        }
        nodeData = newNodeData

        // Filter and re-index wires
        var wiresToRemove: [Wire] = []
        var wiresToAdd: [Wire] = []

        for wire in flowPatch.wires {
            let fromNode = wire.output.nodeIndex
            let toNode = wire.input.nodeIndex

            // Mark wires connected to deleted node for removal
            if fromNode == index || toNode == index {
                wiresToRemove.append(wire)
            } else if fromNode > index || toNode > index {
                // Re-index nodes after deleted one
                wiresToRemove.append(wire)
                let newFromNode = fromNode > index ? fromNode - 1 : fromNode
                let newToNode = toNode > index ? toNode - 1 : toNode
                wiresToAdd.append(Wire(
                    from: OutputID(newFromNode, wire.output.portIndex),
                    to: InputID(newToNode, wire.input.portIndex)
                ))
            }
        }

        for wire in wiresToRemove {
            flowPatch.wires.remove(wire)
        }
        for wire in wiresToAdd {
            flowPatch.wires.insert(wire)
        }
    }

    /// Get the descriptor for a node at an index
    public func descriptor(at index: Int) -> NodeDescriptor? {
        guard let data = nodeData[index] else { return nil }
        return NodeRegistry.shared.descriptor(for: data.nodeType)
    }

    /// Update a property value for a node
    public mutating func setProperty(_ key: String, value: Double, forNodeAt index: Int) {
        nodeData[index]?.propertyValues[key] = value
    }
}

// MARK: - Example Patches

extension ElementaryPatch {
    /// Create a simple sine oscillator patch
    public static func sineOscillator() -> ElementaryPatch {
        var patch = ElementaryPatch()

        guard let constDesc = NodeRegistry.shared.descriptor(for: "const"),
              let cycleDesc = NodeRegistry.shared.descriptor(for: "cycle"),
              let mulDesc = NodeRegistry.shared.descriptor(for: "mul"),
              let outDesc = NodeRegistry.shared.descriptor(for: "out") else {
            return patch
        }

        // Create nodes
        let freqNode = patch.addNode(descriptor: constDesc, at: CGPoint(x: 100, y: 100))
        patch.setProperty("value", value: 440, forNodeAt: freqNode)

        let oscNode = patch.addNode(descriptor: cycleDesc, at: CGPoint(x: 300, y: 100))

        let gainNode = patch.addNode(descriptor: constDesc, at: CGPoint(x: 100, y: 200))
        patch.setProperty("value", value: 0.5, forNodeAt: gainNode)

        let mulNode = patch.addNode(descriptor: mulDesc, at: CGPoint(x: 500, y: 150))

        let outNode = patch.addNode(descriptor: outDesc, at: CGPoint(x: 700, y: 150))

        // Connect: freq -> cycle -> mul -> out
        //          gain --------^
        patch.connect(from: freqNode, to: oscNode, inputPort: 0)
        patch.connect(from: oscNode, to: mulNode, inputPort: 0)
        patch.connect(from: gainNode, to: mulNode, inputPort: 1)
        patch.connect(from: mulNode, to: outNode, inputPort: 0)

        return patch
    }

    /// Create an FM synthesis patch
    public static func fmSynth() -> ElementaryPatch {
        var patch = ElementaryPatch()

        guard let constDesc = NodeRegistry.shared.descriptor(for: "const"),
              let cycleDesc = NodeRegistry.shared.descriptor(for: "cycle"),
              let mulDesc = NodeRegistry.shared.descriptor(for: "mul"),
              let addDesc = NodeRegistry.shared.descriptor(for: "add"),
              let outDesc = NodeRegistry.shared.descriptor(for: "out") else {
            return patch
        }

        // Modulator
        let modFreqNode = patch.addNode(descriptor: constDesc, at: CGPoint(x: 100, y: 50))
        patch.setProperty("value", value: 220, forNodeAt: modFreqNode)

        let modOscNode = patch.addNode(descriptor: cycleDesc, at: CGPoint(x: 300, y: 50))

        let modDepthNode = patch.addNode(descriptor: constDesc, at: CGPoint(x: 100, y: 150))
        patch.setProperty("value", value: 200, forNodeAt: modDepthNode)

        let modMulNode = patch.addNode(descriptor: mulDesc, at: CGPoint(x: 500, y: 100))

        // Carrier
        let carrierFreqNode = patch.addNode(descriptor: constDesc, at: CGPoint(x: 100, y: 250))
        patch.setProperty("value", value: 440, forNodeAt: carrierFreqNode)

        let addNode = patch.addNode(descriptor: addDesc, at: CGPoint(x: 500, y: 200))

        let carrierOscNode = patch.addNode(descriptor: cycleDesc, at: CGPoint(x: 700, y: 200))

        // Output
        let gainNode = patch.addNode(descriptor: constDesc, at: CGPoint(x: 500, y: 300))
        patch.setProperty("value", value: 0.3, forNodeAt: gainNode)

        let outMulNode = patch.addNode(descriptor: mulDesc, at: CGPoint(x: 900, y: 250))

        let outNode = patch.addNode(descriptor: outDesc, at: CGPoint(x: 1100, y: 250))

        // Connect modulator
        patch.connect(from: modFreqNode, to: modOscNode, inputPort: 0)
        patch.connect(from: modOscNode, to: modMulNode, inputPort: 0)
        patch.connect(from: modDepthNode, to: modMulNode, inputPort: 1)

        // Connect carrier with modulation
        patch.connect(from: carrierFreqNode, to: addNode, inputPort: 0)
        patch.connect(from: modMulNode, to: addNode, inputPort: 1)
        patch.connect(from: addNode, to: carrierOscNode, inputPort: 0)

        // Connect output
        patch.connect(from: carrierOscNode, to: outMulNode, inputPort: 0)
        patch.connect(from: gainNode, to: outMulNode, inputPort: 1)
        patch.connect(from: outMulNode, to: outNode, inputPort: 0)

        return patch
    }
}
