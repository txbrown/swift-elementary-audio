#pragma once

#include "./ElementaryAudio/runtime/elem/GraphNode.h"
#include "BlockContext.h"

class CustomNode : public elem::GraphNode<float> {
public:
    CustomNode(int32_t id, float sampleRate, int32_t blockSize)
        : elem::GraphNode<float>(id, sampleRate, blockSize) {}

    int setProperty(std::string const& key, elem::js::Value const& val) override;
    void process(elem::FloatBlockContext const& ctx) override;

    // Non-virtual wrapper methods
    int setPropertyWrapper(const char* key, float value);
    void processWrapper(elem::FloatBlockContext ctx);

private:
    float value { 0.5f };
};
