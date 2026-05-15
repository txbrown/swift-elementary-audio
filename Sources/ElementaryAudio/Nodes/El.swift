import Foundation

/// The Elementary Audio node factory namespace
///
/// `El` provides factory functions for creating all built-in Elementary Audio
/// node types. Use these functions to construct audio processing graphs.
///
/// ## Example
///
/// ```swift
/// // Simple sine wave
/// let sine = El.cycle(440) * 0.5
///
/// // FM synthesis
/// let modulator = El.cycle(220) * 200
/// let carrier = El.cycle(440 + modulator) * 0.3
///
/// // Filtered sawtooth
/// let saw = El.blepsaw(110)
/// let filtered = El.svf(.lowpass, 1000, 4, saw)
/// ```
public enum El {
    // MARK: - Constants & Core

    /// Creates a constant signal
    ///
    /// - Parameter value: The constant value
    /// - Returns: A signal that outputs the constant value
    public static func const(_ value: Double) -> Signal {
        Signal(ConstNode(value))
    }

    /// Creates a constant signal with a key for live updates.
    ///
    /// The `key` enables in-place value updates via `setProperty(nodeId:key:value:)`
    /// without rebuilding the graph.
    ///
    /// - Parameters:
    ///   - key: Unique key for runtime property updates
    ///   - value: The constant value
    /// - Returns: A keyed constant signal
    public static func const(key: String, value: Double) -> Signal {
        Signal(KeyedConstNode(key: key, value: value))
    }

    /// Creates a signal representing the current sample rate
    ///
    /// - Returns: A signal containing the sample rate in Hz
    public static func sr() -> Signal {
        Signal(SampleRateNode())
    }

    /// Creates an input signal from the specified channel
    ///
    /// - Parameter channel: The input channel index (default 0)
    /// - Returns: A signal representing the input audio
    public static func input(channel: Int = 0) -> Signal {
        Signal(InputNode(channel: channel))
    }

    // MARK: - Math Functions

    /// Computes the sine of the input signal
    public static func sin(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.sin, x))
    }

    /// Computes the cosine of the input signal
    public static func cos(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.cos, x))
    }

    /// Computes the tangent of the input signal
    public static func tan(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.tan, x))
    }

    /// Computes the hyperbolic tangent (soft clipping)
    public static func tanh(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.tanh, x))
    }

    /// Computes the natural logarithm
    public static func ln(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.ln, x))
    }

    /// Computes the base-10 logarithm
    public static func log(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.log, x))
    }

    /// Computes the base-2 logarithm
    public static func log2(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.log2, x))
    }

    /// Computes the square root
    public static func sqrt(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.sqrt, x))
    }

    /// Computes e raised to the power of x
    public static func exp(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.exp, x))
    }

    /// Computes the absolute value
    public static func abs(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.abs, x))
    }

    /// Rounds up to the nearest integer
    public static func ceil(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.ceil, x))
    }

    /// Rounds down to the nearest integer
    public static func floor(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.floor, x))
    }

    /// Rounds to the nearest integer
    public static func round(_ x: Signal) -> Signal {
        Signal(UnaryMathNode(.round, x))
    }

    // MARK: - Comparison & Binary Math
    //
    // These mirror the operator overloads in NodeOperators.swift (<, <=, >, >=, %).
    // Both APIs are intentional: operators enable natural math-like expressions
    // (e.g., `phasor < delayed`), while El.* functions provide explicit DSP graph
    // construction that reads clearly in composed pipelines (e.g., `El.lt(a, b)`).

    /// Less than comparison (returns 1 if a < b, else 0)
    public static func le(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.le, a, b))
    }

    /// Less than or equal comparison (returns 1 if a <= b, else 0)
    public static func leq(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.leq, a, b))
    }

    /// Greater than comparison (returns 1 if a > b, else 0)
    public static func ge(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.ge, a, b))
    }

    /// Greater than or equal comparison (returns 1 if a >= b, else 0)
    public static func geq(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.geq, a, b))
    }

    /// Equality comparison (returns 1 if a == b, else 0)
    public static func eq(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.eq, a, b))
    }

    /// Modulo (a mod b)
    public static func mod(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.mod, a, b))
    }

    /// Minimum of two signals
    public static func min(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.min, a, b))
    }

    /// Maximum of two signals
    public static func max(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.max, a, b))
    }

    /// Raises a to the power of b
    public static func pow(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.pow, a, b))
    }

    /// Logical AND (returns 1 if both a and b are non-zero)
    public static func and(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.and, a, b))
    }

    /// Logical OR (returns 1 if either a or b is non-zero)
    public static func or(_ a: Signal, _ b: Signal) -> Signal {
        Signal(BinaryMathNode(.or, a, b))
    }

    // MARK: - Oscillators

    /// Creates a phasor (ramp oscillator from 0 to 1)
    ///
    /// - Parameter frequency: The frequency in Hz
    /// - Returns: A signal ramping from 0 to 1 at the given frequency
    public static func phasor(_ frequency: Signal) -> Signal {
        Signal(PhasorNode(frequency: frequency))
    }

    public static func phasor(_ frequency: Double) -> Signal {
        phasor(Signal(frequency))
    }

    /// Creates a sine wave oscillator
    ///
    /// This is a convenience function that creates a phasor and applies
    /// a sine function to generate a sine wave.
    ///
    /// - Parameter frequency: The frequency in Hz
    /// - Returns: A sine wave signal at the given frequency
    public static func cycle(_ frequency: Signal) -> Signal {
        sin(phasor(frequency) * 2.0 * .pi)
    }

    public static func cycle(_ frequency: Double) -> Signal {
        cycle(Signal(frequency))
    }

    /// Creates a PolyBLEP sawtooth oscillator
    ///
    /// - Parameter frequency: The frequency in Hz
    /// - Returns: A band-limited sawtooth wave
    public static func blepsaw(_ frequency: Signal) -> Signal {
        Signal(BlepSawNode(frequency: frequency))
    }

    public static func blepsaw(_ frequency: Double) -> Signal {
        blepsaw(Signal(frequency))
    }

    /// Creates a PolyBLEP square wave oscillator
    ///
    /// - Parameter frequency: The frequency in Hz
    /// - Returns: A band-limited square wave
    public static func blepsquare(_ frequency: Signal) -> Signal {
        Signal(BlepSquareNode(frequency: frequency))
    }

    public static func blepsquare(_ frequency: Double) -> Signal {
        blepsquare(Signal(frequency))
    }

    /// Creates a PolyBLEP triangle wave oscillator
    ///
    /// - Parameter frequency: The frequency in Hz
    /// - Returns: A band-limited triangle wave
    public static func bleptriangle(_ frequency: Signal) -> Signal {
        Signal(BlepTriangleNode(frequency: frequency))
    }

    public static func bleptriangle(_ frequency: Double) -> Signal {
        bleptriangle(Signal(frequency))
    }

    /// Creates white noise
    ///
    /// - Returns: A signal of uniform random noise in the range [-1, 1]
    public static func noise() -> Signal {
        Signal(NoiseNode())
    }

    // MARK: - Filters

    /// Creates a one-pole lowpass filter
    ///
    /// - Parameters:
    ///   - coefficient: The filter coefficient (0 to 1)
    ///   - input: The input signal
    /// - Returns: The filtered signal
    public static func pole(_ coefficient: Signal, _ input: Signal) -> Signal {
        Signal(OnePoleNode(coefficient: coefficient, input: input))
    }

    public static func pole(_ coefficient: Double, _ input: Signal) -> Signal {
        pole(Signal(coefficient), input)
    }

    /// Creates an envelope follower
    ///
    /// - Parameters:
    ///   - attack: Attack time coefficient
    ///   - release: Release time coefficient
    ///   - input: The input signal
    /// - Returns: The envelope signal
    public static func env(_ attack: Signal, _ release: Signal, _ input: Signal) -> Signal {
        Signal(EnvelopeNode(attack: attack, release: release, input: input))
    }

    /// State variable filter mode
    public enum SVFMode: String, Sendable {
        case lowpass, highpass, bandpass, notch, allpass
    }

    /// Creates a state variable filter
    ///
    /// - Parameters:
    ///   - mode: The filter mode
    ///   - frequency: Cutoff frequency in Hz
    ///   - q: Resonance (Q factor)
    ///   - input: The input signal
    /// - Returns: The filtered signal
    public static func svf(_ mode: SVFMode, _ frequency: Signal, _ q: Signal, _ input: Signal) -> Signal {
        Signal(SVFNode(mode: mode, frequency: frequency, q: q, input: input))
    }

    public static func svf(_ mode: SVFMode, _ frequency: Double, _ q: Double, _ input: Signal) -> Signal {
        svf(mode, Signal(frequency), Signal(q), input)
    }

    // MARK: - Delays

    /// Creates a single-sample delay (z^-1)
    ///
    /// - Parameter input: The input signal
    /// - Returns: The input delayed by one sample
    public static func z(_ input: Signal) -> Signal {
        Signal(SingleSampleDelayNode(input: input))
    }

    /// Creates a fixed-length sample delay
    ///
    /// - Parameters:
    ///   - size: The delay length in samples
    ///   - input: The input signal
    /// - Returns: The delayed signal
    public static func sdelay(_ size: Int, _ input: Signal) -> Signal {
        Signal(SampleDelayNode(size: size, input: input))
    }

    /// Creates a variable delay line
    ///
    /// - Parameters:
    ///   - size: Maximum delay length in samples
    ///   - time: Current delay time in samples
    ///   - input: The input signal
    /// - Returns: The delayed signal
    public static func delay(_ size: Int, _ time: Signal, _ input: Signal) -> Signal {
        Signal(DelayNode(size: size, time: time, input: input))
    }

    // MARK: - Control

    /// Creates a sample-and-hold (latch)
    ///
    /// - Parameters:
    ///   - trigger: When this goes high, the input is sampled
    ///   - input: The signal to sample
    /// - Returns: The latched signal
    public static func latch(_ trigger: Signal, _ input: Signal) -> Signal {
        Signal(LatchNode(trigger: trigger, input: input))
    }

    /// Creates a counter that increments on each trigger
    ///
    /// - Parameter gate: The trigger signal
    /// - Returns: A signal that counts trigger events
    public static func counter(_ gate: Signal) -> Signal {
        Signal(CounterNode(gate: gate))
    }

    // MARK: - Sequences

    /// Steps through a pattern of values on each trigger pulse (seq2).
    ///
    /// The `key` enables in-place `seq` updates via `setPropertyArray`
    /// without resetting the counter position.
    ///
    /// - Parameters:
    ///   - key: Unique key for in-place seq updates
    ///   - seq: Array of values to sequence through
    ///   - hold: Whether to hold values between steps (default true)
    ///   - loop: Whether to loop the sequence (default true)
    ///   - trigger: The trigger signal that advances the sequence
    ///   - gate: The gate signal (typically a playing/on-off control)
    /// - Returns: The sequenced signal
    public static func seq2(key: String, seq: [Double], hold: Bool = true, loop: Bool = true, _ trigger: Signal, _ gate: Signal) -> Signal {
        Signal(Seq2Node(key: key, seq: seq, hold: hold, loop: loop, trigger: trigger, gate: gate))
    }

    /// Creates a step sequencer
    ///
    /// - Parameters:
    ///   - trigger: Trigger signal to advance the sequence
    ///   - values: Array of values to sequence through
    ///   - hold: Whether to hold the last value (default true)
    ///   - loop: Whether to loop the sequence (default true)
    /// - Returns: The sequenced signal
    public static func seq(_ trigger: Signal, _ values: [Double], hold: Bool = true, loop: Bool = true) -> Signal {
        Signal(SequenceNode(trigger: trigger, values: values, hold: hold, loop: loop))
    }

    // MARK: - Sync Phasor

    /// Creates a phasor that resets to 0 on the rising edge of a gate signal.
    ///
    /// Used for transport clock synchronization: ramps from 0–1 at the given
    /// frequency, but resets to 0 when the gate transitions from 0 to 1.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz
    ///   - gate: The gate signal (resets phasor on 0→1 transition)
    /// - Returns: A resettable phasor signal
    public static func syncphasor(_ frequency: Signal, _ gate: Signal) -> Signal {
        Signal(SyncPhasorNode(frequency: frequency, reset: gate))
    }

    public static func syncphasor(_ frequency: Double, _ gate: Signal) -> Signal {
        syncphasor(Signal(frequency), gate)
    }

    // MARK: - Sample Playback

    /// Plays a sample from the VFS in trigger mode (drums, one-shots)
    ///
    /// - Parameters:
    ///   - path: VFS key of the loaded audio resource
    ///   - mode: Playback mode ("trigger" or "gate")
    ///   - key: Optional unique key for in-place updates
    ///   - trigger: Trigger signal (plays sample on rising edge)
    ///   - rate: Playback rate (1.0 = normal, 2.0 = octave up, etc.)
    /// - Returns: The sample playback signal
    public static func sample(path: String, mode: String = "trigger", key: String? = nil, _ trigger: Signal, _ rate: Signal) -> Signal {
        Signal(SampleNode(path: path, mode: mode, key: key, trigger: trigger, rate: rate))
    }

    // MARK: - Multiply

    /// Element-wise multiplication of two signals.
    ///
    /// Prefer the `*` operator for simple multiplication. Use `El.mul` when
    /// building the explicit DSP graph node (e.g., for keyed updates via `MulNode`).
    ///
    /// - Parameters:
    ///   - a: First signal
    ///   - b: Second signal
    /// - Returns: The product signal
    public static func mul(_ a: Signal, _ b: Signal) -> Signal {
        Signal(MulNode(a, b))
    }

    public static func mul(_ a: Signal, _ b: Double) -> Signal {
        mul(a, Signal(b))
    }

    public static func mul(_ a: Double, _ b: Signal) -> Signal {
        mul(Signal(a), b)
    }

    // MARK: - Analysis

    /// Creates a level meter
    ///
    /// - Parameters:
    ///   - name: Optional name for the meter (for event identification)
    ///   - input: The signal to meter
    /// - Returns: The input signal (pass-through)
    public static func meter(_ name: String? = nil, _ input: Signal) -> Signal {
        Signal(MeterNode(name: name, input: input))
    }

    /// Creates an oscilloscope capture
    ///
    /// - Parameters:
    ///   - name: Optional name for the scope
    ///   - size: Buffer size in samples (default 512)
    ///   - input: The signal to capture
    /// - Returns: The input signal (pass-through)
    public static func scope(_ name: String? = nil, size: Int = 512, _ input: Signal) -> Signal {
        Signal(ScopeNode(name: name, size: size, input: input))
    }

    // MARK: - Feedback

    /// Creates a feedback tap input point
    ///
    /// - Parameters:
    ///   - name: Unique name for the tap point
    ///   - input: The signal to feed back
    /// - Returns: The input signal (for chaining)
    public static func tapIn(_ name: String, _ input: Signal) -> Signal {
        Signal(TapInNode(name: name, input: input))
    }

    /// Reads from a feedback tap point
    ///
    /// - Parameter name: The name of the tap point to read from
    /// - Returns: The signal from the tap point (delayed by one block)
    public static func tapOut(_ name: String) -> Signal {
        Signal(TapOutNode(name: name))
    }
}

// MARK: - Pi Constant

extension Double {
    /// The mathematical constant pi, for convenience in DSL expressions
    public static let pi = Double.pi
}
