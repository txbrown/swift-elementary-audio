#include "CustomNode.h"
#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int CustomNode::setProperty(std::string const &key,
                            elem::js::Value const &val) {
    float floatVal = static_cast<float>(static_cast<elem::js::Number>(val));

    if (key == "value") {
        value.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "frequency") {
        freq.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "waveform") {
        waveform.store(static_cast<int>(floatVal), std::memory_order_relaxed);
        return 1;
    }
    if (key == "synthMode") {
        synthMode.store(static_cast<int>(floatVal), std::memory_order_relaxed);
        return 1;
    }
    if (key == "modFreqRatio") {
        modFreqRatio.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "modDepth") {
        modDepth.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "filterCutoff") {
        filterCutoff.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "filterQ") {
        filterQ.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "lfoRate") {
        lfoRate.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "lfoDepth") {
        lfoDepth.store(floatVal, std::memory_order_relaxed);
        return 1;
    }
    if (key == "lfoTarget") {
        lfoTarget.store(static_cast<int>(floatVal), std::memory_order_relaxed);
        return 1;
    }

    return 0;
}

float CustomNode::generateWaveform(float p, WaveformType type) {
    switch (type) {
        case WaveformType::Sine:
            return std::sin(2.0f * M_PI * p);

        case WaveformType::Saw:
            return 2.0f * p - 1.0f;

        case WaveformType::Square:
            return p < 0.5f ? 1.0f : -1.0f;

        case WaveformType::Triangle:
            return 4.0f * std::abs(p - 0.5f) - 1.0f;

        case WaveformType::Noise:
            return generateNoise();

        default:
            return std::sin(2.0f * M_PI * p);
    }
}

float CustomNode::generateNoise() {
    // Simple xorshift PRNG
    noiseState ^= noiseState << 13;
    noiseState ^= noiseState >> 17;
    noiseState ^= noiseState << 5;
    return (static_cast<float>(noiseState) / static_cast<float>(UINT32_MAX)) * 2.0f - 1.0f;
}

float CustomNode::applyFilter(float input, float cutoff, float q) {
    // Simple one-pole lowpass filter
    const float sampleRate = getSampleRate();
    const float omega = 2.0f * M_PI * std::min(cutoff, sampleRate * 0.45f) / sampleRate;
    const float g = omega / (1.0f + omega);

    // Two-pole filter for resonance
    const float resonance = std::max(0.0f, std::min(q, 20.0f)) / 20.0f;
    const float feedback = resonance * 4.0f;

    float v = input - filterZ2 * feedback;
    float lowpass = filterZ1 + g * (v - filterZ1);
    filterZ1 = lowpass;
    filterZ2 = filterZ2 + g * (lowpass - filterZ2);

    return filterZ2;
}

void CustomNode::process(elem::FloatBlockContext const &ctx) {
    // Load all parameters once per block for efficiency
    const float currentFreq = freq.load(std::memory_order_relaxed);
    const float currentValue = value.load(std::memory_order_relaxed);
    const WaveformType currentWaveform = static_cast<WaveformType>(waveform.load(std::memory_order_relaxed));
    const SynthMode currentMode = static_cast<SynthMode>(synthMode.load(std::memory_order_relaxed));
    const float currentModRatio = modFreqRatio.load(std::memory_order_relaxed);
    const float currentModDepth = modDepth.load(std::memory_order_relaxed);
    const float currentCutoff = filterCutoff.load(std::memory_order_relaxed);
    const float currentQ = filterQ.load(std::memory_order_relaxed);
    const float currentLfoRate = lfoRate.load(std::memory_order_relaxed);
    const float currentLfoDepth = lfoDepth.load(std::memory_order_relaxed);
    const int currentLfoTarget = lfoTarget.load(std::memory_order_relaxed);

    const float sampleRate = getSampleRate();
    const float phaseIncrement = currentFreq / sampleRate;
    const float modPhaseIncrement = (currentFreq * currentModRatio) / sampleRate;
    const float lfoPhaseIncrement = currentLfoRate / sampleRate;

    // Detuning for unison mode
    const float detune1 = 0.995f;
    const float detune2 = 1.005f;

    for (int i = 0; i < ctx.numSamples; ++i) {
        float sample = 0.0f;

        // Calculate LFO value
        float lfoValue = std::sin(2.0f * M_PI * lfoPhase);
        lfoPhase += lfoPhaseIncrement;
        if (lfoPhase >= 1.0f) lfoPhase -= 1.0f;

        // Apply LFO to targets
        float ampMod = 1.0f;
        float freqMod = 0.0f;
        float cutoffMod = 1.0f;

        if (currentLfoTarget == 1) {
            ampMod = 0.5f + 0.5f * lfoValue * currentLfoDepth + (1.0f - currentLfoDepth) * 0.5f;
        } else if (currentLfoTarget == 2) {
            freqMod = lfoValue * currentLfoDepth * 20.0f; // ±20Hz vibrato
        } else if (currentLfoTarget == 3) {
            cutoffMod = 0.5f + 0.5f * (lfoValue * currentLfoDepth + 1.0f);
        }

        float effectiveFreq = currentFreq + freqMod;
        float effectivePhaseInc = effectiveFreq / sampleRate;

        switch (currentMode) {
            case SynthMode::Simple: {
                sample = generateWaveform(phase, currentWaveform);
                phase += effectivePhaseInc;
                break;
            }

            case SynthMode::FM: {
                // FM synthesis
                float modulator = std::sin(2.0f * M_PI * modPhase) * currentModDepth / sampleRate;
                float fmPhase = phase + modulator;
                fmPhase = fmPhase - std::floor(fmPhase); // Wrap to 0-1
                sample = generateWaveform(fmPhase, currentWaveform);

                phase += effectivePhaseInc;
                modPhase += modPhaseIncrement;
                break;
            }

            case SynthMode::Additive: {
                // Additive synthesis - 4 harmonics
                sample = generateWaveform(phase, WaveformType::Sine) * 0.5f;

                float h2Phase = std::fmod(phase * 2.0f, 1.0f);
                sample += generateWaveform(h2Phase, WaveformType::Sine) * 0.25f;

                float h3Phase = std::fmod(phase * 3.0f, 1.0f);
                sample += generateWaveform(h3Phase, WaveformType::Sine) * 0.125f;

                float h4Phase = std::fmod(phase * 4.0f, 1.0f);
                sample += generateWaveform(h4Phase, WaveformType::Sine) * 0.0625f;

                phase += effectivePhaseInc;
                break;
            }

            case SynthMode::Unison: {
                // Detuned unison - 3 oscillators
                float osc1 = generateWaveform(phase, currentWaveform);
                float osc2 = generateWaveform(phase2, currentWaveform);
                float osc3 = generateWaveform(phase3, currentWaveform);
                sample = (osc1 + osc2 + osc3) / 3.0f;

                phase += effectivePhaseInc;
                phase2 += effectivePhaseInc * detune1;
                phase3 += effectivePhaseInc * detune2;
                break;
            }

            case SynthMode::Filtered: {
                // Oscillator through filter
                float raw = generateWaveform(phase, currentWaveform);
                sample = applyFilter(raw, currentCutoff * cutoffMod, currentQ);
                phase += effectivePhaseInc;
                break;
            }
        }

        // Wrap phases
        if (phase >= 1.0f) phase -= 1.0f;
        if (modPhase >= 1.0f) modPhase -= 1.0f;
        if (phase2 >= 1.0f) phase2 -= 1.0f;
        if (phase3 >= 1.0f) phase3 -= 1.0f;

        // Apply amplitude modulation and final volume
        ctx.outputData[i] = sample * currentValue * ampMod;
    }
}

// Wrapper methods implementation
int CustomNode::setPropertyWrapper(const char *key, float val) {
    return setProperty(std::string(key), elem::js::Value(val));
}

void CustomNode::processWrapper(const elem::FloatBlockContext &ctx) {
    process(ctx);
}
