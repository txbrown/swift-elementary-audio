#include "CustomNode.h"
#include <algorithm>

int CustomNode::setProperty(std::string const& key, elem::js::Value const& val) {
    if (key == "value") {
        value = static_cast<float>(static_cast<elem::js::Number>(val));
        return 1;
    }
    return 0;
}

void CustomNode::process(elem::FloatBlockContext const& ctx) {
    std::fill_n(ctx.outputData, ctx.numSamples, value);
}

// Wrapper methods implementation
int CustomNode::setPropertyWrapper(const char* key, float val) {
    return setProperty(std::string(key), elem::js::Value(val));
}

void CustomNode::processWrapper(elem::FloatBlockContext ctx) {
    process(ctx);
}
