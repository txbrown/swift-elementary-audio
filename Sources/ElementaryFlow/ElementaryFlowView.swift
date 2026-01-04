import SwiftUI
import Flow

/// Main view for the Elementary Flow node editor
public struct ElementaryFlowView: View {
    @Binding var patch: ElementaryPatch
    @State private var selection: Set<NodeIndex> = []
    @State private var showingNodePicker = false
    @State private var errorMessage: String?

    public init(patch: Binding<ElementaryPatch>) {
        self._patch = patch
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Node Editor (no extra gestures - they conflict with Flow's internal gestures)
            NodeEditor(patch: $patch.flowPatch, selection: $selection)
                .onNodeMoved { index, location in
                    // Node was moved - patch is updated automatically
                }
                .onWireAdded { wire in
                    // Wire was added - patch is updated automatically
                }
                .onWireRemoved { wire in
                    // Wire was removed - patch is updated automatically
                }

            // Add Node button
            Button(action: { showingNodePicker = true }) {
                Label("Add Node", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .padding()

            // Error overlay
            if let error = errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(error)
                            .foregroundColor(.white)
                        Button("Dismiss") {
                            errorMessage = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingNodePicker) {
            NodePickerView { descriptor in
                addNode(descriptor: descriptor)
                showingNodePicker = false
            }
        }
    }

    private func addNode(descriptor: NodeDescriptor) {
        // Place new node at a default position with some randomness to avoid overlap
        let position = CGPoint(
            x: CGFloat.random(in: 100...400),
            y: CGFloat.random(in: 100...300)
        )
        _ = patch.addNode(descriptor: descriptor, at: position)
    }
}

/// Node picker organized by category
public struct NodePickerView: View {
    let onSelect: (NodeDescriptor) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onSelect: @escaping (NodeDescriptor) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(NodeCategory.allCases, id: \.self) { category in
                    let descriptors = NodeRegistry.shared.descriptors(in: category)
                    if !descriptors.isEmpty {
                        Section(header: categoryHeader(category)) {
                            ForEach(descriptors) { descriptor in
                                Button(action: { onSelect(descriptor) }) {
                                    HStack {
                                        Circle()
                                            .fill(category.color)
                                            .frame(width: 12, height: 12)
                                        Text(descriptor.displayName)
                                        Spacer()
                                        Text(descriptor.nodeType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 300, minHeight: 400)
        #endif
    }

    private func categoryHeader(_ category: NodeCategory) -> some View {
        HStack {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)
            Text(category.rawValue)
        }
    }
}

/// View for editing node properties
public struct NodePropertiesView: View {
    let nodeIndex: Int
    @Binding var patch: ElementaryPatch

    public init(nodeIndex: Int, patch: Binding<ElementaryPatch>) {
        self.nodeIndex = nodeIndex
        self._patch = patch
    }

    public var body: some View {
        Group {
            if let data = patch.nodeData[nodeIndex],
               let descriptor = NodeRegistry.shared.descriptor(for: data.nodeType) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(descriptor.displayName)
                        .font(.headline)

                    ForEach(descriptor.properties) { property in
                        propertyEditor(for: property, data: data)
                    }
                }
                .padding()
            } else {
                Text("Select a node to edit properties")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func propertyEditor(for property: PropertyDescriptor, data: ElementaryNodeData) -> some View {
        let value = data.propertyValues[property.id] ?? property.defaultValue

        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .font(.caption)
                .foregroundColor(.secondary)

            if let range = property.range {
                HStack {
                    Slider(
                        value: Binding(
                            get: { value },
                            set: { patch.setProperty(property.id, value: $0, forNodeAt: nodeIndex) }
                        ),
                        in: range
                    )
                    Text(String(format: "%.2f", value))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 50)
                }
            } else {
                TextField(
                    property.name,
                    value: Binding(
                        get: { value },
                        set: { patch.setProperty(property.id, value: $0, forNodeAt: nodeIndex) }
                    ),
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}

/// Complete demo view with node editor and controls
public struct ElementaryFlowDemoView: View {
    @State private var patch = ElementaryPatch.sineOscillator()
    @State private var selection: Set<NodeIndex> = []
    @State private var isPlaying = false
    @State private var showingNodePicker = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        HSplitView {
            // Main editor
            VStack(spacing: 0) {
                // Toolbar
                toolbar
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Node editor
                NodeEditor(patch: $patch.flowPatch, selection: $selection)
            }

            // Properties panel
            VStack(alignment: .leading) {
                Text("Properties")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                Divider()

                if let selectedIndex = selection.first {
                    NodePropertiesView(nodeIndex: selectedIndex, patch: $patch)
                } else {
                    VStack {
                        Spacer()
                        Text("Select a node")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Spacer()

                // Error display
                if let error = errorMessage {
                    VStack {
                        Divider()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(error)
                                .font(.caption)
                        }
                        .padding()
                    }
                    .background(Color.red.opacity(0.1))
                }
            }
            .frame(minWidth: 250, maxWidth: 300)
        }
        .sheet(isPresented: $showingNodePicker) {
            NodePickerView { descriptor in
                _ = patch.addNode(descriptor: descriptor, at: CGPoint(x: 300, y: 200))
                showingNodePicker = false
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Button(action: { showingNodePicker = true }) {
                Label("Add Node", systemImage: "plus")
            }

            Button(action: deleteSelected) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selection.isEmpty)

            Divider()
                .frame(height: 20)

            Button(action: { patch = ElementaryPatch.sineOscillator() }) {
                Text("Sine Demo")
            }

            Button(action: { patch = ElementaryPatch.fmSynth() }) {
                Text("FM Demo")
            }

            Spacer()

            Button(action: validateGraph) {
                Label("Validate", systemImage: "checkmark.circle")
            }

            Button(action: togglePlayback) {
                Label(isPlaying ? "Stop" : "Play", systemImage: isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func deleteSelected() {
        for index in selection.sorted().reversed() {
            patch.removeNode(at: index)
        }
        selection.removeAll()
    }

    private func validateGraph() {
        do {
            _ = try PatchConverter.convert(patch)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func togglePlayback() {
        if isPlaying {
            isPlaying = false
            // Stop audio...
        } else {
            do {
                let graph = try PatchConverter.convert(patch)
                errorMessage = nil
                isPlaying = true
                // Start audio with graph...
                print("Graph built successfully with \(graph.roots.count) output(s)")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#if DEBUG
#Preview {
    ElementaryFlowDemoView()
        .frame(width: 1000, height: 600)
}
#endif
