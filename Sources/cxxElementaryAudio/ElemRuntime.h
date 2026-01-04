#pragma once
#include "./ElementaryAudio/runtime/elem/Runtime.h"
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

    // Delete a node
    int32_t deleteNode(int32_t nodeId) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(1)); // DELETE_NODE
        instruction.push_back(elem::js::Number(nodeId));

        elem::js::Array batch;
        batch.push_back(instruction);

        return runtime->applyInstructions(batch);
    }

    // Append a child node to a parent
    int32_t appendChild(int32_t parentId, int32_t childId) {
        if (!runtime) return -1;

        elem::js::Array instruction;
        instruction.push_back(elem::js::Number(2)); // APPEND_CHILD
        instruction.push_back(elem::js::Number(parentId));
        instruction.push_back(elem::js::Number(childId));

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

private:
    std::unique_ptr<elem::Runtime<float>> runtime;

    ElemRuntime()
        : runtime(std::make_unique<elem::Runtime<float>>(44100.0, 512)) {}

    ~ElemRuntime() = default;
} SWIFT_IMMORTAL_REFERENCE;
