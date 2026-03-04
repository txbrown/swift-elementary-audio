import XCTest
@testable import ElementaryAudio

final class ComparisonNodeTests: XCTestCase {
    // MARK: - El.le (less than)

    func testLeCreatesCorrectNodeType() {
        let a: Signal = 1.0
        let b: Signal = 2.0
        let result = El.le(a, b)
        XCTAssertEqual(result.underlyingNode.nodeType, "le")
    }

    func testLeHasTwoChildrenInCorrectOrder() {
        let a = El.const(1.0)
        let b = El.const(2.0)
        let result = El.le(a, b)
        XCTAssertEqual(result.underlyingNode.children.count, 2)
        XCTAssertEqual(result.underlyingNode.children[0].nodeId, a.underlyingNode.nodeId)
        XCTAssertEqual(result.underlyingNode.children[1].nodeId, b.underlyingNode.nodeId)
    }

    // MARK: - El.leq (less than or equal)

    func testLeqCreatesCorrectNodeType() {
        let result = El.leq(Signal(1.0), Signal(2.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "leq")
    }

    // MARK: - El.ge (greater than)

    func testGeCreatesCorrectNodeType() {
        let result = El.ge(Signal(1.0), Signal(2.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "ge")
    }

    func testGeHasChildrenInCorrectOrder() {
        let a = El.const(5.0)
        let b = El.const(3.0)
        let result = El.ge(a, b)
        XCTAssertEqual(result.underlyingNode.children[0].nodeId, a.underlyingNode.nodeId)
        XCTAssertEqual(result.underlyingNode.children[1].nodeId, b.underlyingNode.nodeId)
    }

    // MARK: - El.geq (greater than or equal)

    func testGeqCreatesCorrectNodeType() {
        let result = El.geq(Signal(1.0), Signal(2.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "geq")
    }

    // MARK: - El.eq (equal)

    func testEqCreatesCorrectNodeType() {
        let result = El.eq(Signal(1.0), Signal(2.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "eq")
    }

    // MARK: - El.mod (modulo)

    func testModCreatesCorrectNodeType() {
        let result = El.mod(Signal(5.0), Signal(3.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "mod")
    }

    // MARK: - El.min

    func testMinCreatesCorrectNodeType() {
        let result = El.min(Signal(1.0), Signal(2.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "min")
    }

    // MARK: - El.max

    func testMaxCreatesCorrectNodeType() {
        let result = El.max(Signal(1.0), Signal(2.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "max")
    }

    // MARK: - El.pow

    func testPowCreatesCorrectNodeType() {
        let result = El.pow(Signal(2.0), Signal(3.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "pow")
    }

    // MARK: - El.and

    func testAndCreatesCorrectNodeType() {
        let result = El.and(Signal(1.0), Signal(1.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "and")
    }

    // MARK: - El.or

    func testOrCreatesCorrectNodeType() {
        let result = El.or(Signal(0.0), Signal(1.0))
        XCTAssertEqual(result.underlyingNode.nodeType, "or")
    }

    // MARK: - Graph Composition

    func testComparisonNodesComposeInGraph() {
        let phasor = El.phasor(440.0)
        let delayed = El.z(phasor)
        let trigger = El.le(phasor, delayed)

        XCTAssertEqual(trigger.underlyingNode.nodeType, "le")
        XCTAssertEqual(trigger.underlyingNode.children.count, 2)
    }

    func testBinaryMathComposesWithSeq() {
        let trigger = El.le(Signal(0.5), Signal(0.3))
        let freq = El.seq(trigger, [880, 660, 660, 660])
        let output = El.cycle(freq) * 0.5

        XCTAssertEqual(output.underlyingNode.nodeType, "mul")
    }
}
