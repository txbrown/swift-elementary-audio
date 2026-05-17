# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Swift Elementary Audio — a declarative Swift DSL for real-time audio processing, wrapping the [Elementary Audio](https://elementary.audio) C++ runtime (v4.0.3) via Swift/C++ interop.

## Build & Test

```bash
swift build          # Build all targets
swift test           # Run all 23 tests (ComparisonNodeTests + GraphRendererProcessTests)
swift run swift-elementary-audio     # Run the macOS SwiftUI demo app
swift run ElementaryPlayground       # Run the visual node editor playground
```

The Example/ directory contains a Tuist-based iOS app (requires `tuist generate`).

## Architecture

```
Swift DSL (Signal, El.*, AudioGraphBuilder)
        ↓
InstructionEncoder → instruction batches (createNode, appendChild, setProperty, activateRoots, commitUpdates)
        ↓
ElemRuntime.h (C++ singleton, applies instructions via elem::Runtime<float>)
        ↓  lock-free rseqQueue
GraphRenderSequence (real-time audio thread)
```

**Three layers, two threads:**
- **Non-RT thread**: Swift DSL → InstructionEncoder → GraphRenderer → ElemRuntime.applyInstructions() → builds new GraphRenderSequence → pushes to lock-free queue
- **RT thread (CoreAudio)**: ElemRuntime.process() → pops latest GraphRenderSequence → runs audio graph

### Key modules

- **cxxElementaryAudio** — C++ target. `ElemRuntime.h` is the singleton bridge exposing graph mutation methods to Swift. `CustomNode.h/.cpp` is a custom GraphNode implementation. Elementary Audio lives as a git submodule at `Sources/cxxElementaryAudio/ElementaryAudio/` with a nested `choc` submodule for BlockEvents.
- **ElementaryAudio** — Swift library. Core types (`AudioNode` protocol, `Signal` wrapper, `NodeID`, `PropertyValue`), DSL (`El.*` factory functions, `AudioGraphBuilder` result builder, operator overloads), and Bridge (`InstructionEncoder`, `GraphRenderer`).
- **ElementaryFlow** — Visual node editor built on the Flow library (vendored in `Vendor/Flow/`).

### How graph rendering works

1. `GraphRenderer.render()` calls `gc()` to clean up stale nodes from previous render
2. `InstructionEncoder.encode()` traverses the `AudioGraph`, encoding each node depth-first: createNode → setProperty → appendChild (with childOutputChannel for v4 multi-channel)
3. Instructions are sent one-by-one to `ElemRuntime` methods which wrap them as `elem::js::Array` batches
4. `activateRoots` + `commitUpdates` triggers `buildRenderSequence()` which pushes a new render sequence to the RT thread via lock-free queue

### C++ interop details

- Swift 5.10+ C++ interop enabled via `.interoperabilityMode(.Cxx)` in Package.swift
- C++20 standard required
- `ElemRuntime` is marked `SWIFT_IMMORTAL_REFERENCE` (singleton)
- `CustomNode` uses `SWIFT_SHARED_REFERENCE` with manual retain/release
- Platform minimums: macOS 13.3, iOS 16.4 (C++ interop requirement)
- The `choc` third-party library is header-only and excluded from SPM compilation in Package.swift

### Elementary Audio v4 API (current)

- `appendChild` requires 3 args: `(parentId, childId, childOutputChannel)` — channel 0 for mono nodes
- `BlockContext.outputData` is `float**` (multi-channel), access as `ctx.outputData[0][i]` for mono
- No `DELETE_NODE` instruction — garbage collection via `Runtime::gc()` (called automatically at start of each `render()`)
- `SharedResourceMap` manages named audio buffers for sample playback nodes (`sample`, `sampleseq`, `table`, etc.)
