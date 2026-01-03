import SwiftUI
import AVFoundation
import CoreAudio
import cxxElementaryAudio
import ElementaryAudio

// MARK: - App Entry Point

@main
struct ElementaryAudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()

    var body: some View {
        NavigationSplitView {
            // Sidebar with categories
            List(selection: $audioManager.selectedCategory) {
                Section("Examples") {
                    ForEach(ExampleCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
            }
            .navigationTitle("Elementary Audio")
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Example selector
                ExampleListView(audioManager: audioManager)

                Divider()

                // Controls and visualization
                ControlPanelView(audioManager: audioManager)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

// MARK: - Example List View

struct ExampleListView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
            ], spacing: 16) {
                ForEach(audioManager.filteredExamples) { example in
                    ExampleCard(
                        example: example,
                        isSelected: audioManager.selectedExample?.id == example.id,
                        isPlaying: audioManager.isPlaying && audioManager.selectedExample?.id == example.id
                    ) {
                        audioManager.selectExample(example)
                    }
                }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Example Card

struct ExampleCard: View {
    let example: AudioExample
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: example.icon)
                        .font(.title2)
                        .foregroundColor(isPlaying ? .green : .accentColor)

                    Spacer()

                    if isPlaying {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.green)
                            .symbolEffect(.variableColor.iterative)
                    }
                }

                Text(example.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(example.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Control Panel View

struct ControlPanelView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 16) {
            // Now Playing
            if let example = audioManager.selectedExample {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(example.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    // Play/Stop Button
                    Button(action: {
                        if audioManager.isPlaying {
                            audioManager.stop()
                        } else {
                            audioManager.play()
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(audioManager.isPlaying ? .red : .green)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                }
            } else {
                Text("Select an example to play")
                    .foregroundColor(.secondary)
            }

            Divider()

            // Parameter Controls
            if audioManager.selectedExample != nil {
                ParameterControlsView(audioManager: audioManager)
            }

            // DSL Code Preview
            if let example = audioManager.selectedExample {
                DSLCodeView(example: example)
            }
        }
        .padding()
        .frame(height: 300)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Parameter Controls

struct ParameterControlsView: View {
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        HStack(spacing: 24) {
            // Frequency Control
            VStack(alignment: .leading) {
                Text("Frequency: \(Int(audioManager.frequency)) Hz")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $audioManager.frequency, in: 100...2000) { _ in
                    audioManager.updateFrequency()
                }
                .frame(width: 200)
            }

            // Volume Control
            VStack(alignment: .leading) {
                Text("Volume: \(Int(audioManager.volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $audioManager.volume, in: 0...1) { _ in
                    audioManager.updateVolume()
                }
                .frame(width: 200)
            }

            Spacer()
        }
    }
}

// MARK: - DSL Code View

struct DSLCodeView: View {
    let example: AudioExample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DSL Code")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(example.code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Audio Manager

@MainActor
class AudioManager: ObservableObject {
    @Published var selectedCategory: ExampleCategory = .basic
    @Published var selectedExample: AudioExample?
    @Published var isPlaying = false
    @Published var frequency: Double = 440
    @Published var volume: Double = 0.5

    private var engine: AudioPlaybackEngine?

    var filteredExamples: [AudioExample] {
        AudioExample.all.filter { $0.category == selectedCategory }
    }

    init() {
        engine = AudioPlaybackEngine()
    }

    func selectExample(_ example: AudioExample) {
        let wasPlaying = isPlaying
        if isPlaying {
            stop()
        }
        selectedExample = example
        frequency = example.defaultFrequency
        engine?.applySettings(example.settings)
        if wasPlaying {
            play()
        }
    }

    func play() {
        guard let example = selectedExample else { return }
        engine?.applySettings(example.settings)
        engine?.setFrequency(Float(frequency))
        engine?.setVolume(Float(volume))
        engine?.start()
        isPlaying = true
    }

    func stop() {
        engine?.stop()
        isPlaying = false
    }

    func updateFrequency() {
        engine?.setFrequency(Float(frequency))
    }

    func updateVolume() {
        engine?.setVolume(Float(volume))
    }
}

// MARK: - Example Category

enum ExampleCategory: String, CaseIterable, Identifiable {
    case basic = "Basic"
    case synthesis = "Synthesis"
    case filters = "Filters"
    case modulation = "Modulation"
    case sequences = "Sequences"
    case complex = "Complex"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .basic: return "waveform"
        case .synthesis: return "pianokeys"
        case .filters: return "slider.horizontal.3"
        case .modulation: return "waveform.path.ecg"
        case .sequences: return "music.note.list"
        case .complex: return "cube.transparent"
        }
    }
}

// MARK: - Synth Settings

struct SynthSettings {
    var waveform: Int = 0      // 0=sine, 1=saw, 2=square, 3=triangle, 4=noise
    var synthMode: Int = 0     // 0=simple, 1=FM, 2=additive, 3=unison, 4=filtered
    var modFreqRatio: Float = 2.0
    var modDepth: Float = 200.0
    var filterCutoff: Float = 2000.0
    var filterQ: Float = 1.0
    var lfoRate: Float = 0.5
    var lfoDepth: Float = 0.5
    var lfoTarget: Int = 0     // 0=none, 1=amplitude, 2=frequency, 3=filter

    static let sine = SynthSettings()
    static let saw = SynthSettings(waveform: 1)
    static let square = SynthSettings(waveform: 2)
    static let triangle = SynthSettings(waveform: 3)
    static let noise = SynthSettings(waveform: 4)

    static let fm = SynthSettings(synthMode: 1, modFreqRatio: 2.0, modDepth: 200.0)
    static let additive = SynthSettings(synthMode: 2)
    static let unison = SynthSettings(waveform: 1, synthMode: 3)

    static let filteredSaw = SynthSettings(waveform: 1, synthMode: 4, filterCutoff: 800.0, filterQ: 4.0)
    static let filterSweep = SynthSettings(waveform: 1, synthMode: 4, filterCutoff: 1000.0, filterQ: 8.0, lfoRate: 0.5, lfoDepth: 0.8, lfoTarget: 3)
    static let resonantFilter = SynthSettings(waveform: 1, synthMode: 4, filterCutoff: 1000.0, filterQ: 15.0)

    static let tremolo = SynthSettings(lfoRate: 5.0, lfoDepth: 0.5, lfoTarget: 1)
    static let vibrato = SynthSettings(lfoRate: 6.0, lfoDepth: 0.5, lfoTarget: 2)
    static let ringMod = SynthSettings(synthMode: 1, modFreqRatio: 0.25, modDepth: 500.0)

    static let synthPatch = SynthSettings(waveform: 1, synthMode: 4, filterCutoff: 1200.0, filterQ: 4.0, lfoRate: 0.3, lfoDepth: 0.5, lfoTarget: 3)
    static let ambientPad = SynthSettings(waveform: 0, synthMode: 2, filterCutoff: 800.0, filterQ: 1.0, lfoRate: 0.1, lfoDepth: 0.3, lfoTarget: 3)
    static let noisyTexture = SynthSettings(waveform: 4, synthMode: 4, filterCutoff: 500.0, filterQ: 2.0)
}

// MARK: - Audio Example

struct AudioExample: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: ExampleCategory
    let icon: String
    let code: String
    let defaultFrequency: Double
    let settings: SynthSettings

    static let all: [AudioExample] = [
        // Basic
        AudioExample(
            name: "Sine Wave",
            description: "Pure sine wave oscillator",
            category: .basic,
            icon: "waveform",
            code: "El.cycle(440.0) * 0.5",
            defaultFrequency: 440,
            settings: .sine
        ),
        AudioExample(
            name: "Sawtooth Wave",
            description: "Bright sawtooth oscillator",
            category: .basic,
            icon: "waveform.circle",
            code: "El.blepsaw(220.0) * 0.3",
            defaultFrequency: 220,
            settings: .saw
        ),
        AudioExample(
            name: "Square Wave",
            description: "Hollow square wave",
            category: .basic,
            icon: "speaker.stereo.fill",
            code: "El.blepsquare(220.0) * 0.3",
            defaultFrequency: 220,
            settings: .square
        ),

        // Synthesis
        AudioExample(
            name: "FM Synthesis",
            description: "Frequency modulation synthesis",
            category: .synthesis,
            icon: "waveform.path",
            code: """
            let mod = El.cycle(220.0) * 200.0
            let carrier = El.cycle(440.0 + mod)
            carrier * 0.3
            """,
            defaultFrequency: 440,
            settings: .fm
        ),
        AudioExample(
            name: "Additive Synthesis",
            description: "Harmonic series (4 partials)",
            category: .synthesis,
            icon: "chart.bar.fill",
            code: """
            let h1 = El.cycle(220.0) * 0.5
            let h2 = El.cycle(440.0) * 0.25
            let h3 = El.cycle(660.0) * 0.125
            (h1 + h2 + h3) * 0.4
            """,
            defaultFrequency: 220,
            settings: .additive
        ),
        AudioExample(
            name: "Detuned Saws",
            description: "Fat unison sawtooth sound",
            category: .synthesis,
            icon: "waveform.badge.plus",
            code: """
            let osc1 = El.blepsaw(218.0)
            let osc2 = El.blepsaw(220.0)
            let osc3 = El.blepsaw(222.0)
            (osc1 + osc2 + osc3) * 0.2
            """,
            defaultFrequency: 220,
            settings: .unison
        ),

        // Filters
        AudioExample(
            name: "Filtered Saw",
            description: "Lowpass filtered sawtooth",
            category: .filters,
            icon: "line.3.horizontal.decrease",
            code: """
            El.blepsaw(110.0)
                .lowpass(frequency: 800.0, q: 4.0)
                .gain(0.4)
            """,
            defaultFrequency: 110,
            settings: .filteredSaw
        ),
        AudioExample(
            name: "Filter Sweep",
            description: "LFO-modulated filter cutoff",
            category: .filters,
            icon: "slider.horizontal.below.rectangle",
            code: """
            let lfo = El.cycle(0.5) * 0.5 + 0.5
            let cutoff = lfo * 1800.0 + 200.0
            El.blepsaw(110.0)
                .lowpass(frequency: cutoff, q: 8.0)
            """,
            defaultFrequency: 110,
            settings: .filterSweep
        ),
        AudioExample(
            name: "Resonant Filter",
            description: "High resonance SVF filter",
            category: .filters,
            icon: "waveform.and.magnifyingglass",
            code: """
            let input = El.blepsaw(110.0)
            El.svf(.lowpass, 1000.0, 15.0, input)
            """,
            defaultFrequency: 110,
            settings: .resonantFilter
        ),

        // Modulation
        AudioExample(
            name: "Tremolo",
            description: "Amplitude modulation effect",
            category: .modulation,
            icon: "waveform.path.ecg",
            code: """
            let signal = El.cycle(440.0)
            let lfo = El.cycle(5.0) * 0.5 + 0.5
            signal * lfo * 0.5
            """,
            defaultFrequency: 440,
            settings: .tremolo
        ),
        AudioExample(
            name: "Vibrato",
            description: "Frequency modulation effect",
            category: .modulation,
            icon: "waveform.circle.fill",
            code: """
            let mod = El.cycle(6.0) * 10.0
            El.cycle(440.0 + mod) * 0.5
            """,
            defaultFrequency: 440,
            settings: .vibrato
        ),
        AudioExample(
            name: "Ring Modulation",
            description: "Ring mod effect",
            category: .modulation,
            icon: "circle.grid.cross",
            code: """
            let carrier = El.cycle(440.0)
            let modulator = El.cycle(110.0)
            carrier * modulator * 0.5
            """,
            defaultFrequency: 440,
            settings: .ringMod
        ),

        // Sequences (using filtered saw for melodic content)
        AudioExample(
            name: "Bass Sequence",
            description: "Deep bass pattern",
            category: .sequences,
            icon: "music.note.list",
            code: """
            let notes = [55.0, 55.0, 82.5, 55.0]
            let trigger = El.phasor(4.0)
            El.blepsaw(El.seq(trigger, notes))
                .lowpass(frequency: 400.0, q: 4.0)
            """,
            defaultFrequency: 55,
            settings: SynthSettings(waveform: 1, synthMode: 4, filterCutoff: 400.0, filterQ: 4.0)
        ),
        AudioExample(
            name: "Acid Lead",
            description: "TB-303 style acid",
            category: .sequences,
            icon: "arrow.up.right",
            code: """
            El.blepsaw(110.0)
                .lowpass(frequency: 800.0, q: 12.0)
            """,
            defaultFrequency: 110,
            settings: SynthSettings(waveform: 1, synthMode: 4, filterCutoff: 800.0, filterQ: 12.0, lfoRate: 2.0, lfoDepth: 0.6, lfoTarget: 3)
        ),

        // Complex
        AudioExample(
            name: "Synth Patch",
            description: "Complete synth voice",
            category: .complex,
            icon: "pianokeys.inverse",
            code: """
            let osc1 = El.blepsaw(220.0)
            let osc2 = El.blepsaw(220.0 * 1.005)
            let filterLFO = El.cycle(0.3) * 500.0 + 1000.0
            (osc1 + osc2)
                .lowpass(frequency: filterLFO, q: 4.0)
            """,
            defaultFrequency: 220,
            settings: .synthPatch
        ),
        AudioExample(
            name: "Ambient Pad",
            description: "Evolving pad texture",
            category: .complex,
            icon: "cloud.fill",
            code: """
            let osc1 = El.cycle(110.0)
            let osc2 = El.cycle(221.0)
            let osc3 = El.cycle(329.0)
            let mix = osc1 * 0.4 + osc2 * 0.3 + osc3 * 0.2
            mix.lowpass(frequency: 800.0, q: 1.0)
            """,
            defaultFrequency: 110,
            settings: .ambientPad
        ),
        AudioExample(
            name: "Noise Texture",
            description: "Filtered noise ambience",
            category: .complex,
            icon: "wind",
            code: """
            El.noise()
                .lowpass(frequency: 500.0, q: 2.0)
                .gain(0.3)
            """,
            defaultFrequency: 500,
            settings: .noisyTexture
        ),
    ]
}

// MARK: - Audio Playback Engine

class AudioPlaybackEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let customNode: CustomNodeWrapper
    private var isRunning = false

    init() {
        customNode = CustomNodeWrapper(id: 1, sampleRate: 44100, blockSize: 512)
        _ = customNode.setProperty("value", value: 0.5)
        _ = customNode.setProperty("frequency", value: 440.0)

        setupAudio()
    }

    private func setupAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let capturedNode = customNode

        let renderBlock: AVAudioSourceNodeRenderBlock = { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first else { return noErr }
            guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let context = elem.FloatBlockContext(
                inputData: nil,
                numInputChannels: 0,
                outputData: ptr,
                numSamples: Int(frameCount),
                userData: nil
            )

            capturedNode.process(context)

            return noErr
        }

        sourceNode = AVAudioSourceNode(format: format, renderBlock: renderBlock)

        if let sourceNode = sourceNode {
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        }
    }

    func start() {
        guard !isRunning else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
    }

    func setFrequency(_ freq: Float) {
        _ = customNode.setProperty("frequency", value: freq)
    }

    func setVolume(_ volume: Float) {
        _ = customNode.setProperty("value", value: volume)
    }

    func applySettings(_ settings: SynthSettings) {
        _ = customNode.setProperty("waveform", value: Float(settings.waveform))
        _ = customNode.setProperty("synthMode", value: Float(settings.synthMode))
        _ = customNode.setProperty("modFreqRatio", value: settings.modFreqRatio)
        _ = customNode.setProperty("modDepth", value: settings.modDepth)
        _ = customNode.setProperty("filterCutoff", value: settings.filterCutoff)
        _ = customNode.setProperty("filterQ", value: settings.filterQ)
        _ = customNode.setProperty("lfoRate", value: settings.lfoRate)
        _ = customNode.setProperty("lfoDepth", value: settings.lfoDepth)
        _ = customNode.setProperty("lfoTarget", value: Float(settings.lfoTarget))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
