import GaeaPluginKit
import GaeaProtocol
import XCTest

@testable import SAMAudioPlugin

/// The MES → engine mapping, without a model: what a separate job asks for and what is refused.
final class PlanTests: XCTestCase {
    func testDescribeIsTrimmedAndLowercased() throws {
        let plan = try separatePlan(params: ["describe": "  Dog Barking "], seed: 7, mixtureSeconds: 10)
        XCTAssertEqual(plan.describe, "dog barking")
        XCTAssertEqual(plan.stems, ["target", "residual"])
        XCTAssertEqual(plan.seed, 7)
        XCTAssertTrue(plan.spans.isEmpty)
    }

    func testStemsNarrowAndSpansSort() throws {
        let plan = try separatePlan(params: ["describe": "speech", "stems": ["residual"],
                                             "spans": [["start_s": 3.0, "end_s": 4.0, "present": false], ["start_s": 0.5, "end_s": 1.0, "present": true]]],
                                    seed: 1, mixtureSeconds: 10)
        XCTAssertEqual(plan.stems, ["residual"])
        XCTAssertEqual(plan.spans.map(\.startSeconds), [0.5, 3.0])
        XCTAssertEqual(plan.spans.map(\.present), [true, false])
        XCTAssertEqual(effective(plan)["describe"], .string("speech"))
        XCTAssertNotNil(effective(plan)["spans"])
    }

    func testASpanWithinAFrameOfTheEndIsTaken() throws {
        let plan = try separatePlan(params: ["describe": "speech", "spans": [["start_s": 8.0, "end_s": 10.03, "present": true]]], seed: 1, mixtureSeconds: 10)
        XCTAssertEqual(plan.spans.first?.endSeconds, 10)
    }

    func testRefusals() {
        let bad: [(String, [String: JSONValue], Double?, String?)] = [
            ("no describe", [:], 10, "unsupported_parameter"),
            ("blank describe", ["describe": "   "], 10, nil),
            ("long describe", ["describe": .string(String(repeating: "a", count: 201))], 10, nil),
            ("another stem", ["describe": "speech", "stems": ["vocals"]], 10, "unsupported_parameter"),
            ("a stem twice", ["describe": "speech", "stems": ["target", "target"]], 10, nil),
            ("a speaker pick", ["describe": "speech", "speaker": ["ordinal": 1]], 10, "unsupported_parameter"),
            ("span backwards", ["describe": "speech", "spans": [["start_s": 2.0, "end_s": 1.0, "present": true]]], 10, nil),
            ("span without present", ["describe": "speech", "spans": [["start_s": 1.0, "end_s": 2.0]]], 10, nil),
            ("overlapping spans", ["describe": "speech", "spans": [["start_s": 1.0, "end_s": 3.0, "present": true], ["start_s": 2.0, "end_s": 4.0, "present": true]]], 10, nil),
            ("span past the end", ["describe": "speech", "spans": [["start_s": 1.0, "end_s": 12.0, "present": true]]], 10, "out_of_limits"),
            ("mixture too long", ["describe": "speech"], 31, "out_of_limits"),
            ("mixture too short", ["describe": "speech"], 0.5, "out_of_limits"),
        ]
        for (label, params, seconds, code) in bad {
            XCTAssertThrowsError(try separatePlan(params: params, seed: 1, mixtureSeconds: seconds), label) { error in
                guard let e = error as? GPPError else { return XCTFail("\(label): \(error)") }
                XCTAssertEqual(e.detail?["mes_code"]?.stringValue, code, label)
            }
        }
    }

    func testTouchingSpansAreFine() throws {
        let plan = try separatePlan(params: ["describe": "speech", "spans": [["start_s": 1.0, "end_s": 2.0, "present": true], ["start_s": 2.0, "end_s": 3.0, "present": false]]],
                                    seed: 1, mixtureSeconds: 10)
        XCTAssertEqual(plan.spans.count, 2)
    }

    func testTheOfferIsDescribedSeparation() {
        XCTAssertEqual(samAudioPlugin.offers.map(\.operation), ["audio.separate"])
        XCTAssertEqual(samAudioPlugin.id, "com.xocialize.gaea.samaudio")
        XCTAssertTrue(notes.contains("lowercase"))
        XCTAssertTrue(licenseNotice.contains("military"))
    }
}
