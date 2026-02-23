import XCTest
@testable import SileroVAD

final class SileroVADTests: XCTestCase {

    // MARK: - SileroVAD Tests

    func testInitialization() throws {
        // Verify that the CoreML model loads successfully
        let vad = try SileroVAD()
        XCTAssertNotNil(vad)
    }

    func testProcessReturnsValidRange() throws {
        let vad = try SileroVAD()

        // All zeros — verify output is in valid range
        let zeros = [Float](repeating: 0.0, count: SileroVAD.chunkSize)
        let prob = try vad.process(zeros)

        XCTAssertGreaterThanOrEqual(prob, 0.0, "Probability must be >= 0")
        XCTAssertLessThanOrEqual(prob, 1.0, "Probability must be <= 1")
    }

    func testProcessRandomNoise() throws {
        let vad = try SileroVAD()

        // Random noise — verify output is in valid range
        let noise = (0..<SileroVAD.chunkSize).map { _ in Float.random(in: -0.01...0.01) }
        let prob = try vad.process(noise)

        XCTAssertGreaterThanOrEqual(prob, 0.0)
        XCTAssertLessThanOrEqual(prob, 1.0)
    }

    func testInvalidChunkSizeTooShort() throws {
        let vad = try SileroVAD()

        let shortChunk = [Float](repeating: 0.0, count: 100)
        XCTAssertThrowsError(try vad.process(shortChunk)) { error in
            guard let vadError = error as? SileroVADError else {
                XCTFail("Expected SileroVADError, got \(type(of: error))")
                return
            }
            if case .invalidChunkSize(let expected, let got) = vadError {
                XCTAssertEqual(expected, 512)
                XCTAssertEqual(got, 100)
            } else {
                XCTFail("Expected invalidChunkSize error, got \(vadError)")
            }
        }
    }

    func testInvalidChunkSizeTooLong() throws {
        let vad = try SileroVAD()

        let longChunk = [Float](repeating: 0.0, count: 1024)
        XCTAssertThrowsError(try vad.process(longChunk))
    }

    func testIsSpeechReturnsBool() throws {
        let vad = try SileroVAD()

        let chunk = [Float](repeating: 0.0, count: SileroVAD.chunkSize)
        // Just verify it returns a Bool without crashing
        let _ = try vad.isSpeech(chunk, threshold: 0.5)
    }

    func testConstants() {
        XCTAssertEqual(SileroVAD.sampleRate, 16000)
        XCTAssertEqual(SileroVAD.chunkSize, 512)
    }

    func testConsecutiveProcessCalls() throws {
        let vad = try SileroVAD()

        // Process multiple chunks in sequence — should not crash
        let chunk = [Float](repeating: 0.0, count: SileroVAD.chunkSize)
        for _ in 0..<10 {
            let prob = try vad.process(chunk)
            XCTAssertGreaterThanOrEqual(prob, 0.0)
            XCTAssertLessThanOrEqual(prob, 1.0)
        }
    }

    func testDifferentInputsProduceDifferentOutputs() throws {

        let silence = [Float](repeating: 0.0, count: SileroVAD.chunkSize)
        let loud = (0..<SileroVAD.chunkSize).map { i in sin(Float(i) * 0.1) * 0.8 }

        // Create fresh instances to avoid state contamination
        let vad1 = try SileroVAD()
        let prob1 = try vad1.process(silence)

        let vad2 = try SileroVAD()
        let prob2 = try vad2.process(loud)

        // They should produce different probabilities (model is discriminative)
        XCTAssertNotEqual(prob1, prob2, accuracy: 0.001,
                         "Different inputs should produce different outputs")
    }

    // MARK: - SileroVADStream Tests

    func testStreamTracksConsecutiveFrames() throws {
        let vad = try SileroVAD()
        let stream = SileroVADStream(vad: vad)

        let chunk = [Float](repeating: 0.0, count: SileroVAD.chunkSize)

        // Process multiple frames with a very high threshold (everything is "silence")
        for i in 0..<5 {
            let result = try stream.process(chunk, threshold: 0.99, requiredFrames: 3)
            XCTAssertEqual(result.consecutiveSilenceFrames, i + 1)
        }
    }

    func testStreamSustainedSilenceDetection() throws {
        let vad = try SileroVAD()
        let stream = SileroVADStream(vad: vad)

        let chunk = [Float](repeating: 0.0, count: SileroVAD.chunkSize)

        // Use high threshold so model output is always below it
        var triggered = false
        for _ in 0..<5 {
            let result = try stream.process(chunk, threshold: 0.99, requiredFrames: 3)
            if result.isSustainedSilence {
                triggered = true
                break
            }
        }
        XCTAssertTrue(triggered, "Should detect sustained silence with high threshold")
    }

    func testStreamReset() throws {
        let vad = try SileroVAD()
        let stream = SileroVADStream(vad: vad)

        let chunk = [Float](repeating: 0.0, count: SileroVAD.chunkSize)

        // Build up frames with a very high threshold
        for _ in 0..<5 {
            _ = try stream.process(chunk, threshold: 0.99, requiredFrames: 3)
        }
        XCTAssertGreaterThan(stream.consecutiveSilenceFrames, 0)

        // Reset
        stream.reset()
        XCTAssertEqual(stream.consecutiveSilenceFrames, 0)
        XCTAssertEqual(stream.lastProbability, 0)
    }

    func testStreamResultContainsProbability() throws {
        let vad = try SileroVAD()
        let stream = SileroVADStream(vad: vad)

        let chunk = [Float](repeating: 0.0, count: SileroVAD.chunkSize)

        let result = try stream.process(chunk)
        XCTAssertGreaterThanOrEqual(result.probability, 0.0)
        XCTAssertLessThanOrEqual(result.probability, 1.0)
        XCTAssertEqual(result.probability, stream.lastProbability)
    }
}
