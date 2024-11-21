#include "CustomNode.h"
#include <algorithm>

int CustomNode::setProperty(std::string const& key, elem::js::Value const& val) {
    if (key == "value") {
        value = static_cast<float>(static_cast<elem::js::Number>(val));
        return 1;
    }

    if (key == "frequency") {
        freq = (elem::js::Number) val;
        return 0;
    }

    return 0;
}

void CustomNode::process(elem::FloatBlockContext const& ctx) {
    for (int i = 0; i < ctx.numSamples; ++i) {
        ctx.outputData[i] = 0.1f * std::sin(2.0f * M_PI * phase);
        phase += freq / getSampleRate();
        if (phase >= 1.0f) phase -= 1.0f;
    }
}

// Wrapper methods implementation
int CustomNode::setPropertyWrapper(const char* key, float val) {
    return setProperty(std::string(key), elem::js::Value(val));
}

void CustomNode::processWrapper(elem::FloatBlockContext ctx) {
    process(ctx);
}
