#pragma once
#include "./ElementaryAudio/runtime/elem/Runtime.h"
#include "./ElementaryAudio/runtime/elem/AudioBufferResource.h"
#include "CustomNode.h"
#include <swift/bridging>
#include <memory>
#include <vector>
#include <string>

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

    // Re-initialize with new sample rate and block size
    void initialize(double sampleRate, int blockSize) {
        runtime = std::make_unique<elem::Runtime<float>>(sampleRate, blockSize);
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

    // Graph rendering methods - exposed to Swift

    // Create a node with the given ID and type
    int32_t createNode(int32_t nodeId, const std::string& nodeType) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(0)); // CREATE_NODE
        instruction.push_back(elem::js::Number(nodeId));
        instruction.push_back(elem::js::String(nodeType));

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Append a child node to a parent (v4: requires childOutputChannel for multi-channel support)
    int32_t appendChild(int32_t parentId, int32_t childId, int32_t childOutputChannel = 0) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(2)); // APPEND_CHILD
        instruction.push_back(elem::js::Number(parentId));
        instruction.push_back(elem::js::Number(childId));
        instruction.push_back(elem::js::Number(childOutputChannel));

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Set a numeric property on a node
    int32_t setPropertyNumber(int32_t nodeId, const std::string& key, double value) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(3)); // SET_PROPERTY
        instruction.push_back(elem::js::Number(nodeId));
        instruction.push_back(elem::js::String(key));
        instruction.push_back(elem::js::Number(value));

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Set a boolean property on a node
    int32_t setPropertyBoolean(int32_t nodeId, const std::string& key, bool value) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(3)); // SET_PROPERTY
        instruction.push_back(elem::js::Number(nodeId));
        instruction.push_back(elem::js::String(key));
        instruction.push_back(elem::js::Boolean(value));

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Set an array property on a node (for seq data, etc.)
    int32_t setPropertyArray(int32_t nodeId, const std::string& key, const double* values, size_t count) {
        if (!runtime) return -1;
        if (count > 0 && values == nullptr) return -1;

        elem::js::Array valArray;
        for (size_t i = 0; i < count; i++) {
            valArray.push_back(elem::js::Number(values[i]));
        }

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(3)); // SET_PROPERTY
        instruction.push_back(elem::js::Number(nodeId));
        instruction.push_back(elem::js::String(key));
        instruction.push_back(valArray);

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Set a string property on a node
    int32_t setPropertyString(int32_t nodeId, const std::string& key, const std::string& value) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(3)); // SET_PROPERTY
        instruction.push_back(elem::js::Number(nodeId));
        instruction.push_back(elem::js::String(key));
        instruction.push_back(elem::js::String(value));

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Activate root nodes and commit (accepts C array for Swift interop)
    int32_t activateRootsAndCommit(const int32_t* rootIds, size_t count) {
        if (!runtime) return -1;

        elem::js::Array batch;

        // ACTIVATE_ROOTS instruction
        elem::js::Array rootsArray;
        if (rootIds != nullptr && count > 0) {
            for (size_t i = 0; i < count; i++) {
                rootsArray.push_back(elem::js::Number(rootIds[i]));
            }
        }

        elem::js::Array activateInstruction;
        activateInstruction.push_back(elem::js::Number(4)); // ACTIVATE_ROOTS
        activateInstruction.push_back(rootsArray);
        batch.push_back(activateInstruction);

        // COMMIT_UPDATES instruction
        elem::js::Array commitInstruction;
        commitInstruction.push_back(elem::js::Number(5)); // COMMIT_UPDATES
        batch.push_back(commitInstruction);

        return runtime->applyInstructions(batch);
    }

    // Explicit garbage collection (v4: replaces implicit deleteNode)
    void gc() {
        if (runtime) {
            runtime->gc();
        }
    }

    // Reset the graph
    void reset() {
        if (runtime) {
            runtime->reset();
        }
    }

    // Explicit shutdown for clean teardown (optional - destructor handles cleanup)
    void shutdown() {
        runtime.reset();
    }

    // ========================================================================
    // VFS / Audio Resource Loading
    // ========================================================================

    // loadAudioFile is intentionally absent: C++ has no access to AVFoundation.
    // Use Swift's VFSLoader.loadAudioFile(key:filePath:) to load files via
    // AVFoundation and then feed the deinterleaved float32 buffers into the
    // runtime via addAudioBuffer() below.

    /// Add a pre-loaded audio buffer to the runtime's shared resource map.
    /// Data format: deinterleaved float32 (ch0 samples, ch1 samples, ...)
    /// Returns true on success, false if key already exists.
    bool addAudioBuffer(const std::string& vfsKey,
                        float** channelData,
                        size_t numChannels,
                        size_t numSamples) {
        if (!runtime) return false;
        
        auto resource = std::make_unique<elem::AudioBufferResource>(
            channelData, numChannels, numSamples);
        return runtime->addSharedResource(vfsKey, std::move(resource));
    }

    /// Add a mono audio buffer to the runtime's shared resource map.
    bool addMonoAudioBuffer(const std::string& vfsKey,
                            float* data,
                            size_t numSamples) {
        if (!runtime) return false;

        auto resource = std::make_unique<elem::AudioBufferResource>(data, numSamples);
        return runtime->addSharedResource(vfsKey, std::move(resource));
    }

private:
    std::unique_ptr<elem::Runtime<float>> runtime;

    ElemRuntime()
        : runtime(std::make_unique<elem::Runtime<float>>(44100.0, 512)) {}

    ~ElemRuntime() = default;
} SWIFT_IMMORTAL_REFERENCE;
