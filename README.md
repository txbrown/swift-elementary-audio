# Swift Elementary Audio

A declarative Swift DSL for real-time audio processing, built on [Elementary Audio](https://elementary.audio).

## Overview

Swift Elementary Audio provides a modern, type-safe Swift API for building audio processing graphs. It wraps the powerful Elementary Audio C++ DSP engine and exposes it through an intuitive declarative syntax.

## Features

- **Declarative DSL** - Build audio graphs using Swift result builders
- **Type-Safe** - Compile-time checked node types and properties
- **40+ Built-in Nodes** - Oscillators, filters, delays, effects, and more
- **Real-Time Safe** - Designed for glitch-free audio processing
- **Async/Await** - Modern Swift concurrency for engine lifecycle
- **Custom Nodes** - Extend with your own DSP implementations

## Requirements

- Swift 5.10+
- macOS 14+ / iOS 15+
- Xcode 15.3+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/txbrown/swift-elementary-audio", from: "1.0.0")
]
```

## Quick Start

```swift
import ElementaryAudio

// Create an audio engine
let engine = try await AudioEngine()

// Render a simple sine wave
try await engine.render {
    El.cycle(440) * 0.5  // 440Hz sine at 50% volume
}

// Start playback
try await engine.start()
```

## Examples

### FM Synthesis

```swift
try await engine.render {
    let modulator = El.cycle(220) * 200
    El.cycle(440 + modulator) * 0.3
}
```

### Filtered Sawtooth with LFO

```swift
try await engine.render {
    let lfo = El.cycle(0.5) * 500 + 1000
    El.blepsaw(110)
        .lowpass(frequency: lfo, q: 4)
        .gain(0.4)
}
```

### Stereo Output

```swift
try await engine.render {
    El.cycle(440) * 0.3  // Left channel
    El.cycle(550) * 0.3  // Right channel
}
```

### Delay Effect

```swift
try await engine.render {
    let dry = El.cycle(440) * 0.3
    let wet = El.delay(44100, El.const(22050), dry) * 0.5
    dry + wet
}
```

### Step Sequencer

```swift
try await engine.render {
    let trigger = El.phasor(4)  // 4Hz trigger
    let notes: [Double] = [261.63, 293.66, 329.63, 349.23]  // C D E F
    let freq = El.seq(trigger, notes)
    El.cycle(freq) * 0.3
}
```

## Node Types

### Oscillators
- `El.cycle(freq)` - Sine wave
- `El.phasor(freq)` - Ramp (0 to 1)
- `El.blepsaw(freq)` - Band-limited sawtooth
- `El.blepsquare(freq)` - Band-limited square
- `El.bleptriangle(freq)` - Band-limited triangle
- `El.noise()` - White noise

### Filters
- `El.svf(mode, freq, q, input)` - State variable filter
- `El.pole(coef, input)` - One-pole lowpass
- `El.env(attack, release, input)` - Envelope follower

### Delays
- `El.z(input)` - Single sample delay
- `El.sdelay(size, input)` - Fixed delay
- `El.delay(size, time, input)` - Variable delay

### Math
- `El.sin(x)`, `El.cos(x)`, `El.tan(x)` - Trigonometry
- `El.tanh(x)` - Soft clipping
- `El.abs(x)`, `El.sqrt(x)`, `El.exp(x)` - Basic math

### Control
- `El.latch(trigger, input)` - Sample and hold
- `El.counter(gate)` - Event counter
- `El.seq(trigger, values)` - Step sequencer

### Analysis
- `El.meter(name, input)` - Level meter
- `El.scope(name, size, input)` - Oscilloscope

### Feedback
- `El.tapIn(name, input)` - Create feedback point
- `El.tapOut(name)` - Read feedback (one block delay)

## Method Chaining

Signals support fluent method chaining:

```swift
El.blepsaw(110)
    .lowpass(frequency: 2000, q: 4)
    .delayed(samples: 4410)
    .gain(0.5)
    .metered(name: "output")
```

## Custom Nodes

Implement the `CustomAudioNode` protocol:

```swift
struct GainNode: CustomAudioNode {
    static let nodeType = "customGain"
    let nodeId = NodeID()
    var children: [any AudioNode] = []
    var properties: NodeProperties = [:]

    private var gain: Float = 1.0

    init(id: NodeID, sampleRate: Double, blockSize: Int) {}

    mutating func setProperty(_ key: String, value: PropertyValue) -> Bool {
        if key == "gain", let v = value.numberValue {
            gain = Float(v)
            return true
        }
        return false
    }

    func process(context: AudioProcessContext) {
        for i in 0..<context.numSamples {
            context.outputData[i] = context.inputData[0][i] * gain
        }
    }
}
```

## Architecture

```
┌─────────────────────────────────────────┐
│           Swift DSL Layer               │
│  (El, Signal, AudioGraphBuilder, etc.)  │
├─────────────────────────────────────────┤
│         Instruction Encoder             │
│    (Encodes graphs to C++ commands)     │
├─────────────────────────────────────────┤
│       C++ Elementary Runtime            │
│   (High-performance audio processing)   │
└─────────────────────────────────────────┘
```

## Thread Safety

- Property updates are thread-safe (use atomic operations)
- The `process()` method runs on the real-time audio thread
- Avoid allocations, locks, or I/O in real-time code

## License

MIT License - see LICENSE file for details.

## Credits

Built on [Elementary Audio](https://elementary.audio) by Nick Thompson.
