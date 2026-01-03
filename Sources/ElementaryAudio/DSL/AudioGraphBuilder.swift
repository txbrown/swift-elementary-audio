import Foundation

/// A result builder for declaratively constructing audio graphs
///
/// `AudioGraphBuilder` enables a SwiftUI-like syntax for building audio
/// processing graphs. Each expression in the builder becomes an output
/// channel.
///
/// ## Example
///
/// ```swift
/// // Mono output
/// @AudioGraphBuilder var mono: AudioGraph {
///     El.cycle(440) * 0.5
/// }
///
/// // Stereo output
/// @AudioGraphBuilder var stereo: AudioGraph {
///     El.cycle(440) * 0.5  // Left channel
///     El.cycle(550) * 0.5  // Right channel
/// }
///
/// // With conditionals
/// @AudioGraphBuilder var conditional: AudioGraph {
///     if useSine {
///         El.cycle(440)
///     } else {
///         El.blepsaw(440)
///     }
/// }
/// ```
@resultBuilder
public struct AudioGraphBuilder {
    /// Build a single signal expression
    public static func buildExpression(_ signal: Signal) -> [Signal] {
        [signal]
    }

    /// Build a single audio node expression
    public static func buildExpression(_ node: any AudioNode) -> [Signal] {
        [Signal(node)]
    }

    /// Build a block of signals
    public static func buildBlock(_ components: [Signal]...) -> [Signal] {
        components.flatMap { $0 }
    }

    /// Build an empty block
    public static func buildBlock() -> [Signal] {
        []
    }

    /// Support for optional (if without else)
    public static func buildOptional(_ component: [Signal]?) -> [Signal] {
        component ?? []
    }

    /// Support for if-else (first branch)
    public static func buildEither(first component: [Signal]) -> [Signal] {
        component
    }

    /// Support for if-else (second branch)
    public static func buildEither(second component: [Signal]) -> [Signal] {
        component
    }

    /// Support for for loops
    public static func buildArray(_ components: [[Signal]]) -> [Signal] {
        components.flatMap { $0 }
    }

    /// Support for #available
    public static func buildLimitedAvailability(_ component: [Signal]) -> [Signal] {
        component
    }

    /// Convert final result to AudioGraph
    public static func buildFinalResult(_ components: [Signal]) -> AudioGraph {
        let roots = components.enumerated().map { index, signal in
            RootNode(channel: index, child: signal)
        }
        return AudioGraph(roots: roots)
    }
}

// MARK: - Convenience Extensions

extension AudioGraph {
    /// Creates an audio graph using the builder syntax
    ///
    /// - Parameter builder: A closure that builds the audio graph
    /// - Returns: The constructed audio graph
    public init(@AudioGraphBuilder _ builder: () -> AudioGraph) {
        self = builder()
    }
}
