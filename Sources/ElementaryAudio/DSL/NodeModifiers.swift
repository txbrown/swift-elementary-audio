import Foundation

// MARK: - Signal Modifiers

extension Signal {
    /// Applies gain to the signal
    ///
    /// - Parameter amount: The gain amount
    /// - Returns: The amplified signal
    public func gain(_ amount: Double) -> Signal {
        self * amount
    }

    /// Applies gain to the signal
    ///
    /// - Parameter amount: The gain signal
    /// - Returns: The amplified signal
    public func gain(_ amount: Signal) -> Signal {
        self * amount
    }

    // MARK: - Filters

    /// Applies a lowpass filter
    ///
    /// - Parameters:
    ///   - frequency: Cutoff frequency in Hz
    ///   - q: Resonance (Q factor, default 1.0)
    /// - Returns: The filtered signal
    public func lowpass(frequency: Signal, q: Signal = Signal(1.0)) -> Signal {
        El.svf(.lowpass, frequency, q, self)
    }

    public func lowpass(frequency: Double, q: Double = 1.0) -> Signal {
        lowpass(frequency: Signal(frequency), q: Signal(q))
    }

    /// Applies a highpass filter
    ///
    /// - Parameters:
    ///   - frequency: Cutoff frequency in Hz
    ///   - q: Resonance (Q factor, default 1.0)
    /// - Returns: The filtered signal
    public func highpass(frequency: Signal, q: Signal = Signal(1.0)) -> Signal {
        El.svf(.highpass, frequency, q, self)
    }

    public func highpass(frequency: Double, q: Double = 1.0) -> Signal {
        highpass(frequency: Signal(frequency), q: Signal(q))
    }

    /// Applies a bandpass filter
    ///
    /// - Parameters:
    ///   - frequency: Center frequency in Hz
    ///   - q: Bandwidth (Q factor)
    /// - Returns: The filtered signal
    public func bandpass(frequency: Signal, q: Signal) -> Signal {
        El.svf(.bandpass, frequency, q, self)
    }

    public func bandpass(frequency: Double, q: Double) -> Signal {
        bandpass(frequency: Signal(frequency), q: Signal(q))
    }

    // MARK: - Delays

    /// Delays the signal by a fixed number of samples
    ///
    /// - Parameter samples: The delay time in samples
    /// - Returns: The delayed signal
    public func delayed(samples: Int) -> Signal {
        El.sdelay(samples, self)
    }

    /// Delays the signal by one sample (z^-1)
    ///
    /// - Returns: The signal delayed by one sample
    public func z() -> Signal {
        El.z(self)
    }

    // MARK: - Dynamics

    /// Applies soft clipping using tanh
    ///
    /// - Returns: The soft-clipped signal
    public func softClip() -> Signal {
        El.tanh(self)
    }

    /// Clips the signal to the range [-1, 1]
    ///
    /// - Returns: The hard-clipped signal
    public func clip() -> Signal {
        max(min(self, Signal(1.0)), Signal(-1.0))
    }

    /// Clips the signal to a custom range
    ///
    /// - Parameters:
    ///   - low: Minimum value
    ///   - high: Maximum value
    /// - Returns: The clipped signal
    public func clip(low: Double, high: Double) -> Signal {
        max(min(self, Signal(high)), Signal(low))
    }

    // MARK: - Math

    /// Computes the absolute value
    public func abs() -> Signal {
        El.abs(self)
    }

    /// Computes the square root
    public func sqrt() -> Signal {
        El.sqrt(self)
    }

    /// Raises to a power
    public func pow(_ exponent: Double) -> Signal {
        ElementaryAudio.pow(self, Signal(exponent))
    }

    // MARK: - Analysis

    /// Attaches a level meter to the signal
    ///
    /// - Parameter name: Optional name for the meter
    /// - Returns: The signal (pass-through)
    public func metered(name: String? = nil) -> Signal {
        El.meter(name, self)
    }

    /// Captures the signal for oscilloscope display
    ///
    /// - Parameters:
    ///   - name: Optional name for the scope
    ///   - size: Buffer size in samples
    /// - Returns: The signal (pass-through)
    public func scoped(name: String? = nil, size: Int = 512) -> Signal {
        El.scope(name, size: size, self)
    }

    // MARK: - Mixing

    /// Mixes this signal with another
    ///
    /// - Parameters:
    ///   - other: The signal to mix with
    ///   - balance: Mix balance (0 = this only, 1 = other only)
    /// - Returns: The mixed signal
    public func mixed(with other: Signal, balance: Double = 0.5) -> Signal {
        self * (1.0 - balance) + other * balance
    }

    /// Mixes this signal with another using a signal-rate balance
    ///
    /// - Parameters:
    ///   - other: The signal to mix with
    ///   - balance: Mix balance signal (0 = this only, 1 = other only)
    /// - Returns: The mixed signal
    public func mixed(with other: Signal, balance: Signal) -> Signal {
        self * (Signal(1.0) - balance) + other * balance
    }
}

// MARK: - Stereo Utilities

/// A stereo signal pair
public struct StereoSignal: Sendable {
    public let left: Signal
    public let right: Signal

    public init(left: Signal, right: Signal) {
        self.left = left
        self.right = right
    }

    /// Creates a stereo signal from a mono signal
    public init(mono: Signal) {
        self.left = mono
        self.right = mono
    }
}

extension Signal {
    /// Pans the signal between left and right channels
    ///
    /// - Parameter amount: Pan position (-1 = left, 0 = center, 1 = right)
    /// - Returns: A stereo signal pair
    public func panned(_ amount: Double) -> StereoSignal {
        let leftGain = El.cos((amount + 1.0) * 0.5 * .pi * 0.5)
        let rightGain = El.sin((amount + 1.0) * 0.5 * .pi * 0.5)
        return StereoSignal(left: self * leftGain, right: self * rightGain)
    }

    /// Pans the signal using a signal-rate pan position
    ///
    /// - Parameter amount: Pan position signal (-1 = left, 0 = center, 1 = right)
    /// - Returns: A stereo signal pair
    public func panned(_ amount: Signal) -> StereoSignal {
        let normalized = (amount + 1.0) * 0.5 * .pi * 0.5
        let leftGain = El.cos(normalized)
        let rightGain = El.sin(normalized)
        return StereoSignal(left: self * leftGain, right: self * rightGain)
    }
}
