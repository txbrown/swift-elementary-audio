#pragma once
#include "./ElementaryAudio/runtime/elem/Runtime.h"
#include "CustomNode.h"
#include <swift/bridging>
#include <memory>

class ElemRuntime {
public:
    // Singleton accessor - guaranteed thread-safe initialization (C++11)
    static ElemRuntime &getInstance() {
        static ElemRuntime instance;
        return instance;
    }

    ElemRuntime(const ElemRuntime &) = delete;
    ElemRuntime &operator=(const ElemRuntime &) = delete;

    // Access the underlying runtime (for advanced use cases)
    elem::Runtime<float>* getRuntime() {
        return runtime.get();
    }

    void registerCustomNode(const char *name) {
        if (runtime) {
            runtime->registerNodeType(name, [](int32_t id, float sr, int32_t bs) {
                return std::make_unique<CustomNode>(id, sr, bs);
            });
        }
    }

    void process(const float **inputData, size_t numInputChannels,
                 float **outputData, size_t numOutputChannels,
                 size_t numSamples) {
        if (runtime) {
            runtime->process(inputData, numInputChannels, outputData,
                             numOutputChannels, numSamples, nullptr);
        }
    }

    // Explicit shutdown for clean teardown (optional - destructor handles cleanup)
    void shutdown() {
        runtime.reset();
    }

private:
    std::unique_ptr<elem::Runtime<float>> runtime;

    ElemRuntime()
        : runtime(std::make_unique<elem::Runtime<float>>(44100.0, 512)) {}

    ~ElemRuntime() = default;
} SWIFT_IMMORTAL_REFERENCE;
