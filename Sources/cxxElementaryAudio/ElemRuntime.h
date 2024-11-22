#pragma once
#include "./ElementaryAudio/runtime/elem/Runtime.h"
#include "CustomNode.h"
#include <swift/bridging>
#include <iostream>

class ElemRuntime {
public:
    elem::Runtime<float> *runtime = nullptr;

    // Singleton-like accessor
    static ElemRuntime &getInstance() {
        static ElemRuntime instance; // Guaranteed to be created once and live for the program's lifetime
        return instance;
    }

    ElemRuntime(const ElemRuntime &) = delete; // Non-copyable
    ElemRuntime &operator=(const ElemRuntime &) = delete;

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

private:
    ElemRuntime() {
        runtime = new elem::Runtime<float>(44100.0, 512);
    }

    ~ElemRuntime() {
        std::cout << "Deleting ElemRuntime";
        if (runtime)
            delete runtime;
    }
} SWIFT_IMMORTAL_REFERENCE;
