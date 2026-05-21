//
//  SequencerNodeTests.swift
//  ElementaryAudioTests
//
//  Structure tests for the new DSL nodes added in YON-127:
//  seq2, syncphasor, sample, mul, and const(key:).
//  No rendering or runtime required — pure graph value inspection.
//

@testable import ElementaryAudio
import XCTest

final class SequencerNodeTests: XCTestCase {
    // MARK: - seq2

    func testSeq2HasCorrectNodeType() {
        let node = El.seq2(key: "test", seq: [1.0, 0.0], El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.nodeType, "seq2")
    }

    func testSeq2HasTwoChildrenInOrder() {
        let trigger = El.const(1.0)
        let gate = El.const(0.0)
        let node = El.seq2(key: "k", seq: [1.0], trigger, gate)
        XCTAssertEqual(node.underlyingNode.children.count, 2)
        XCTAssertEqual(node.underlyingNode.children[0].nodeId, trigger.underlyingNode.nodeId)
        XCTAssertEqual(node.underlyingNode.children[1].nodeId, gate.underlyingNode.nodeId)
    }

    func testSeq2StoresKeyInProperties() {
        let node = El.seq2(key: "my-seq", seq: [0.5, 1.0], El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["key"], .string("my-seq"))
    }

    func testSeq2StoresSeqArrayInProperties() {
        let pattern = [1.0, 0.5, 0.0, 0.5]
        let node = El.seq2(key: "k", seq: pattern, El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["seq"], .array(pattern))
    }

    func testSeq2DefaultHoldAndLoopAreTrue() {
        let node = El.seq2(key: "k", seq: [1.0], El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["hold"], .boolean(true))
        XCTAssertEqual(node.underlyingNode.properties["loop"], .boolean(true))
    }

    func testSeq2RespectsHoldFalse() {
        let node = El.seq2(key: "k", seq: [1.0], hold: false, El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["hold"], .boolean(false))
    }

    // MARK: - syncphasor

    func testSyncphasorHasCorrectNodeType() {
        let node = El.syncphasor(4.0, El.const(1.0))
        XCTAssertEqual(node.underlyingNode.nodeType, "sphasor")
    }

    func testSyncphasorHasTwoChildrenInOrder() {
        let freq = El.const(4.0)
        let gate = El.const(1.0)
        let node = El.syncphasor(freq, gate)
        XCTAssertEqual(node.underlyingNode.children.count, 2)
        XCTAssertEqual(node.underlyingNode.children[0].nodeId, freq.underlyingNode.nodeId)
        XCTAssertEqual(node.underlyingNode.children[1].nodeId, gate.underlyingNode.nodeId)
    }

    // MARK: - sample

    func testSampleHasCorrectNodeType() {
        let node = El.sample(path: "kick", El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.nodeType, "sample")
    }

    func testSampleStoresPathAndMode() {
        let node = El.sample(path: "snare", mode: "gate", El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["path"], .string("snare"))
        XCTAssertEqual(node.underlyingNode.properties["mode"], .string("gate"))
    }

    func testSampleDefaultModeIsTrigger() {
        let node = El.sample(path: "hat", El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["mode"], .string("trigger"))
    }

    func testSampleOptionalKeyIsAbsentWhenNotProvided() {
        let node = El.sample(path: "hat", El.const(1.0), El.const(1.0))
        XCTAssertNil(node.underlyingNode.properties["key"])
    }

    func testSampleOptionalKeyIsStoredWhenProvided() {
        let node = El.sample(path: "hat", key: "hat-key", El.const(1.0), El.const(1.0))
        XCTAssertEqual(node.underlyingNode.properties["key"], .string("hat-key"))
    }

    // MARK: - mul

    func testMulHasCorrectNodeType() {
        let node = El.mul(El.const(1.0), El.const(0.5))
        XCTAssertEqual(node.underlyingNode.nodeType, "mul")
    }

    func testMulHasTwoChildrenInOrder() {
        let a = El.const(1.0)
        let b = El.const(0.5)
        let node = El.mul(a, b)
        XCTAssertEqual(node.underlyingNode.children.count, 2)
        XCTAssertEqual(node.underlyingNode.children[0].nodeId, a.underlyingNode.nodeId)
        XCTAssertEqual(node.underlyingNode.children[1].nodeId, b.underlyingNode.nodeId)
    }

    func testMulWithDoubleRhsCreatesCorrectChildren() {
        let signal = El.const(0.8)
        let node = El.mul(signal, 0.5)
        XCTAssertEqual(node.underlyingNode.children.count, 2)
        XCTAssertEqual(node.underlyingNode.children[0].nodeId, signal.underlyingNode.nodeId)
    }

    // MARK: - const(key:)

    func testKeyedConstHasCorrectNodeType() {
        let node = El.const(key: "tempo", value: 120.0)
        XCTAssertEqual(node.underlyingNode.nodeType, "const")
    }

    func testKeyedConstStoresKeyAndValue() {
        let node = El.const(key: "playing", value: 1.0)
        XCTAssertEqual(node.underlyingNode.properties["key"], .string("playing"))
        XCTAssertEqual(node.underlyingNode.properties["value"], .number(1.0))
    }

    func testKeyedConstHasNoChildren() {
        let node = El.const(key: "vol", value: 0.8)
        XCTAssertTrue(node.underlyingNode.children.isEmpty)
    }
}
