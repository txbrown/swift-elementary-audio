#pragma once

#include "./ElementaryAudio/runtime/elem/GraphNode.h"
#include "BlockContext.h"
#include <atomic>
#include <memory>
#include <swift/bridging>

using FloatBlockContext = elem::FloatBlockContext;

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

private:
    std::atomic<int> refCount;
    float value{0.5f};
    float phase{0.0f};
    float freq{440.0f};
} SWIFT_SHARED_REFERENCE(retainCustomNode, releaseCustomNode);

// Free functions for Swift reference counting
inline void retainCustomNode(CustomNode *node) {
    if (node) node->retain();
}

inline void releaseCustomNode(CustomNode *node) {
    if (node) node->release();
}
