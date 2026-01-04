import SwiftUI
import ElementaryFlow
import ElementaryAudio
import AVFoundation
import cxxElementaryAudio
import Flow

@main
struct ElementaryPlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            PlaygroundView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

// MARK: - Audio Engine using Elementary Runtime

@MainActor
class PlaygroundAudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let renderer = GraphRenderer()

    @Published var isPlaying = false
    @Published var lastRenderError: String?

    init() {
        // Initialize the Elementary runtime
        ElemRuntime.getInstance().initialize(44100.0, 512)
        setupAudio()
    }

    private func setupAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

        let renderBlock: AVAudioSourceNodeRenderBlock = { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Prepare output channel pointers
            var outputPtrs: [UnsafeMutablePointer<Float>?] = []
            for buffer in ablPointer {
                outputPtrs.append(buffer.mData?.assumingMemoryBound(to: Float.self))
            }
            let numChannels = outputPtrs.count

            // Call the Elementary runtime - no input channels for now
            outputPtrs.withUnsafeMutableBufferPointer { outputBuffer in
                let runtime = ElemRuntime.getInstance()
                runtime.process(
                    nil,  // No input data
                    0,    // No input channels
                    outputBuffer.baseAddress,
                    numChannels,
                    Int(frameCount)
                )
            }

            return noErr
        }

        sourceNode = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        if let sourceNode = sourceNode {
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        }
    }

    /// Render an ElementaryPatch to the audio engine
    func renderPatch(_ patch: ElementaryPatch) {
        lastRenderError = nil

        do {
            // Convert patch to AudioGraph using the semantic Swift DSL
            let graph = try PatchConverter.convert(patch)

            // Render the new graph (runtime handles replacement internally)
            try renderer.render(graph)

            print("[Audio] Rendered graph with \(graph.roots.count) output(s)")
        } catch let error as PatchConverter.ConversionError {
            if case .noOutputNode = error {
                // No output node - just log, don't try to modify runtime
                // Previous audio continues until a valid graph is rendered
                print("[Audio] No output node in patch")
            } else {
                lastRenderError = error.description
                print("[Audio] Conversion error: \(error.description)")
            }
        } catch {
            lastRenderError = error.localizedDescription
            print("[Audio] Render error: \(error)")
        }
    }

    func start() {
        guard !isPlaying else { return }
        do {
            try engine.start()
            isPlaying = true
        } catch {
            print("Failed to start audio: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        isPlaying = false
    }

    func toggle() {
        if isPlaying { stop() } else { start() }
    }
}

// MARK: - Main Playground View

// Custom layout for smaller, more compact nodes
private func compactLayout() -> LayoutConstants {
    var layout = LayoutConstants()
    layout.nodeWidth = 140
    layout.nodeTitleHeight = 28
    layout.portSize = CGSize(width: 14, height: 14)
    layout.portSpacing = 6
    layout.nodeSpacing = 30
    layout.nodeTitleFont = .system(size: 12, weight: .semibold)
    layout.portNameFont = .system(size: 10)
    layout.nodeCornerRadius = 4
    return layout
}

struct PlaygroundView: View {
    @StateObject private var audioEngine = PlaygroundAudioEngine()
    @State private var patch = ElementaryPatch.sineOscillator()
    @State private var selection: Set<Int> = []
    @State private var showingInspector = true
    @State private var graphError: String?
    @State private var graphValid = false
    @State private var showConsole = true

    private let nodeLayout = compactLayout()

    var body: some View {
        HSplitView {
            // Left: Node palette
            nodePalette
                .frame(minWidth: 180, maxWidth: 220)

            // Center: Node editor + console
            VStack(spacing: 0) {
                toolbar
                Divider()

                VSplitView {
                    nodeEditor

                    if showConsole {
                        consoleView
                            .frame(minHeight: 100, maxHeight: 200)
                    }
                }
            }

            // Right: Inspector
            if showingInspector {
                inspector
                    .frame(minWidth: 250, maxWidth: 300)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            validateAndRender()
        }
    }

    // MARK: - Node Palette

    private var nodePalette: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Nodes")
                    .font(.headline)
                Spacer()
                Text("\(NodeRegistry.shared.allDescriptors().count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(NodeCategory.allCases, id: \.self) { category in
                        let descriptors = NodeRegistry.shared.descriptors(in: category)
                        if !descriptors.isEmpty {
                            paletteSection(category: category, descriptors: descriptors)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func paletteSection(category: NodeCategory, descriptors: [NodeDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(descriptors.count)")
                    .font(.caption2)
                    .foregroundColor(Color.gray)
            }

            ForEach(descriptors) { descriptor in
                paletteNode(descriptor: descriptor, category: category)
            }
        }
    }

    private func paletteNode(descriptor: NodeDescriptor, category: NodeCategory) -> some View {
        Button(action: { addNode(descriptor) }) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(category.color.opacity(0.3))
                    .frame(width: 4, height: 20)
                Text(descriptor.displayName)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help("\(descriptor.nodeType) - \(descriptor.inputs.count) input(s)")
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Audio controls
            Button(action: { audioEngine.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioEngine.isPlaying ? "Stop" : "Play")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(audioEngine.isPlaying ? .red : .green)
            .keyboardShortcut(.space, modifiers: [])

            Button(action: { renderPatch() }) {
                Label("Render", systemImage: "arrow.triangle.2.circlepath")
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()
                .frame(height: 20)

            // Actions
            Button(action: validateGraph) {
                Label("Validate", systemImage: "checkmark.circle")
            }
            .keyboardShortcut("b", modifiers: .command)

            Button(action: deleteSelected) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selection.isEmpty)
            .keyboardShortcut(.delete, modifiers: [])

            Divider()
                .frame(height: 20)

            // Presets
            Menu {
                Button("Sine Oscillator") { loadPreset(.sineOscillator()) }
                Button("FM Synthesis") { loadPreset(.fmSynth()) }
                Divider()
                Button("Clear All") { clearPatch() }
            } label: {
                Label("Presets", systemImage: "square.grid.2x2")
            }

            Spacer()

            // Graph status
            HStack(spacing: 6) {
                Circle()
                    .fill(graphValid ? .green : (graphError != nil ? .red : .gray))
                    .frame(width: 8, height: 8)
                Text(graphValid ? "Valid" : (graphError != nil ? "Error" : "Building..."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Toggles
            Button(action: { showConsole.toggle() }) {
                Image(systemName: "terminal")
            }
            .buttonStyle(.bordered)
            .help("Toggle Console")

            Button(action: { showingInspector.toggle() }) {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.bordered)
            .help("Toggle Inspector")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Node Editor

    private var nodeEditor: some View {
        Group {
            if patch.flowPatch.nodes.isEmpty {
                // Empty state - only show when no nodes
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Add nodes from the palette")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Double-click or drag from palette")
                        .font(.caption)
                        .foregroundColor(Color.gray)

                    Button("Load Example") {
                        loadPreset(.sineOscillator())
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                // Node editor with compact layout
                NodeEditor(patch: $patch.flowPatch, selection: $selection, layout: nodeLayout)
                    .onWireAdded { _ in validateAndRender() }
                    .onWireRemoved { _ in validateAndRender() }
            }
        }
    }

    // MARK: - Console

    private var consoleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Console")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                if graphError != nil {
                    Button("Clear") {
                        graphError = nil
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let error = graphError {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    } else if graphValid {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Graph is valid and ready to render")
                                .font(.system(size: 11, design: .monospaced))
                        }

                        Text("Nodes: \(patch.flowPatch.nodes.count) | Wires: \(patch.flowPatch.wires.count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Add an output node to complete the graph")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    // MARK: - Inspector

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspector")
                .font(.headline)
                .padding()

            Divider()

            if let selectedIndex = selection.first {
                nodeInspector(index: selectedIndex)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "cursorarrow.click")
                        .font(.largeTitle)
                        .foregroundColor(Color.gray)
                    Text("Select a node")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            Divider()

            graphInfo
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func nodeInspector(index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let data = patch.nodeData[index],
                   let descriptor = NodeRegistry.shared.descriptor(for: data.nodeType) {

                    // Header
                    HStack {
                        Circle()
                            .fill(descriptor.category.color)
                            .frame(width: 12, height: 12)
                        Text(descriptor.displayName)
                            .font(.headline)
                        Spacer()
                    }

                    Text(descriptor.nodeType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    // Description
                    if !descriptor.description.isEmpty {
                        Text(descriptor.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }

                    Divider()

                    // Inputs info
                    if !descriptor.inputs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inputs")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(descriptor.inputs) { input in
                                HStack {
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 1.5)
                                        .frame(width: 8, height: 8)
                                    Text(input.name)
                                        .font(.system(size: 12))
                                    Spacer()
                                    if let defaultVal = input.defaultValue {
                                        Text(formatNumber(defaultVal))
                                            .font(.caption)
                                            .foregroundColor(Color.gray)
                                    }
                                }
                            }
                        }
                    }

                    // Output info
                    if descriptor.hasOutput {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("Signal")
                                    .font(.system(size: 12))
                            }
                        }
                    }

                    // Properties
                    if !descriptor.properties.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Properties")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(descriptor.properties) { property in
                                propertyEditor(
                                    property: property,
                                    value: data.propertyValues[property.id] ?? property.defaultValue,
                                    nodeIndex: index
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func propertyEditor(property: PropertyDescriptor, value: Double, nodeIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .font(.caption)

            if let range = property.range {
                HStack {
                    Slider(
                        value: Binding(
                            get: { value },
                            set: { newValue in
                                patch.setProperty(property.id, value: newValue, forNodeAt: nodeIndex)
                                validateAndRender()
                            }
                        ),
                        in: range
                    )
                    Text(formatNumber(value))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 50)
                }
            } else {
                TextField(
                    "",
                    value: Binding(
                        get: { value },
                        set: { newValue in
                            patch.setProperty(property.id, value: newValue, forNodeAt: nodeIndex)
                            validateAndRender()
                        }
                    ),
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var graphInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Graph Stats")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                VStack(alignment: .leading) {
                    Text("\(patch.flowPatch.nodes.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Nodes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("\(patch.flowPatch.wires.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Wires")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("\(outputCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Outputs")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private var outputCount: Int {
        patch.nodeData.values.filter { $0.nodeType == "out" }.count
    }

    // MARK: - Actions

    private func addNode(_ descriptor: NodeDescriptor) {
        let position = CGPoint(
            x: CGFloat.random(in: 200...600),
            y: CGFloat.random(in: 100...400)
        )
        let index = patch.addNode(descriptor: descriptor, at: position)
        selection = [index]
        validateAndRender()
    }

    private func deleteSelected() {
        for index in selection.sorted().reversed() {
            patch.removeNode(at: index)
        }
        selection.removeAll()
        validateAndRender()
    }

    private func validateGraph() {
        graphError = nil
        graphValid = false

        do {
            let graph = try PatchConverter.convert(patch)
            graphValid = true
            print("Graph valid: \(graph.roots.count) output(s)")
        } catch let error as PatchConverter.ConversionError {
            if case .noOutputNode = error {
                // Not an error, just incomplete
                graphError = nil
            } else {
                graphError = error.description
            }
        } catch {
            graphError = error.localizedDescription
        }
    }

    private func renderPatch() {
        audioEngine.renderPatch(patch)
        if let error = audioEngine.lastRenderError {
            graphError = error
        }
    }

    private func validateAndRender() {
        validateGraph()
        if graphValid {
            renderPatch()
        }
        // If invalid, previous audio continues until valid graph is rendered
    }

    private func loadPreset(_ preset: ElementaryPatch) {
        patch = preset
        selection.removeAll()
        validateAndRender()
    }

    private func clearPatch() {
        patch = ElementaryPatch()
        selection.removeAll()
        graphError = nil
        graphValid = false
        // Audio continues until a new valid graph is rendered
    }

    private func formatNumber(_ value: Double) -> String {
        if value == Double(Int(value)) {
            return "\(Int(value))"
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Preview

#Preview {
    PlaygroundView()
        .frame(width: 1200, height: 800)
}
