#pragma once

#include "./ElementaryAudio/runtime/elem/GraphNode.h"
#include "BlockContext.h"
#include <atomic>
#include <memory>
#include <swift/bridging>

using FloatBlockContext = elem::FloatBlockContext;

// Waveform types
enum class WaveformType : int {
    Sine = 0,
    Saw = 1,
    Square = 2,
    Triangle = 3,
    Noise = 4
};

// Synthesis modes
enum class SynthMode : int {
    Simple = 0,      // Single oscillator
    FM = 1,          // FM synthesis
    Additive = 2,    // Harmonic series
    Unison = 3,      // Detuned oscillators
    Filtered = 4     // Oscillator + filter
};

class CustomNode : public elem::GraphNode<float> {
public:
    CustomNode(int32_t id, float sampleRate, int32_t blockSize)
        : elem::GraphNode<float>(id, sampleRate, blockSize), refCount(1) {}

    // Make destructor public and virtual
    virtual ~CustomNode() = default;

    // Static factory method (use this instead of make_unique)
    static CustomNode* create(int32_t id, float sampleRate, int32_t blockSize) {
        return new CustomNode(id, sampleRate, blockSize);
    }

    void retain() {
        refCount.fetch_add(1, std::memory_order_relaxed);
    }

    void release() {
        if (refCount.fetch_sub(1, std::memory_order_acq_rel) == 1) {
            delete this;
        }
    }

    int setProperty(std::string const &key, elem::js::Value const &val) override;
    void process(elem::FloatBlockContext const &ctx) override;

    // Swift-friendly wrapper methods
    int setPropertyWrapper(const char *key, float val);
    void processWrapper(const elem::FloatBlockContext &ctx);

    // Swift-friendly process that takes a raw output buffer (avoids needing to construct BlockContext from Swift)
    void processSimple(float* outputBuffer, size_t numSamples);

private:
    std::atomic<int> refCount;

    // Thread-safe properties: written from non-RT thread, read from RT thread
    std::atomic<float> value{0.5f};          // Volume/amplitude
    std::atomic<float> freq{440.0f};         // Base frequency
    std::atomic<int> waveform{0};            // WaveformType
    std::atomic<int> synthMode{0};           // SynthMode

    // FM parameters
    std::atomic<float> modFreqRatio{2.0f};   // Modulator freq ratio
    std::atomic<float> modDepth{200.0f};     // Modulation depth in Hz

    // Filter parameters
    std::atomic<float> filterCutoff{2000.0f};
    std::atomic<float> filterQ{1.0f};

    // LFO parameters
    std::atomic<float> lfoRate{0.5f};        // LFO speed in Hz
    std::atomic<float> lfoDepth{0.5f};       // LFO amount (0-1)
    std::atomic<int> lfoTarget{0};           // 0=none, 1=amplitude, 2=frequency, 3=filter

    // Phase accumulators (RT thread only)
    float phase{0.0f};
    float modPhase{0.0f};
    float lfoPhase{0.0f};
    float phase2{0.0f};  // For detuned/unison
    float phase3{0.0f};

    // Filter state (RT thread only)
    float filterZ1{0.0f};
    float filterZ2{0.0f};

    // Noise state
    uint32_t noiseState{12345};

    // Helper functions
    float generateWaveform(float p, WaveformType type);
    float generateNoise();
    float applyFilter(float input, float cutoff, float q);
} SWIFT_SHARED_REFERENCE(retainCustomNode, releaseCustomNode);

// Free functions for Swift reference counting
inline void retainCustomNode(CustomNode *node) {
    if (node) node->retain();
}

inline void releaseCustomNode(CustomNode *node) {
    if (node) node->release();
}
