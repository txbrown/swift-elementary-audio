#pragma once
#include "./ElementaryAudio/runtime/elem/Runtime.h"
#include "CustomNode.h"

struct ElemRuntime {
    elem::Runtime<float>* runtime = nullptr;
    
    ElemRuntime() {
        runtime = new elem::Runtime<float>(44100.0, 512);
    }
    
    ~ElemRuntime() {
        if (runtime) delete runtime;
    }
    
    void registerCustomNode(const char* name) {
        if (runtime) {
            runtime->registerNodeType(name, [](int32_t id, float sr, int32_t bs) {
                return std::make_unique<CustomNode>(id, sr, bs);
            });
        }
    }
    
    void process(const float** inputData, size_t numInputChannels,
                float** outputData, size_t numOutputChannels,  
                size_t numSamples) {

        if (runtime) {
            runtime->process(inputData, numInputChannels,
                           outputData, numOutputChannels,
                           numSamples, nullptr);
        }
    }
};
