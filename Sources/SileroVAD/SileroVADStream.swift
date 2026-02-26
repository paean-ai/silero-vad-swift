// Copyright (c) 2026 Pæan™
// Licensed under the MIT License. See LICENSE for details.

import Foundation

/// Streaming wrapper around `SileroVAD` that tracks consecutive silence frames.
///
/// Use this when you need to detect sustained silence (e.g., for auto-chunking
/// recordings at natural speech pauses).
///
/// ## Usage
///
/// ```swift
/// let vad = try SileroVAD()
/// let stream = SileroVADStream(vad: vad)
///
/// // In your audio callback:
/// let result = try stream.process(chunk, threshold: 0.3, requiredFrames: 16)
/// if result.isSustainedSilence {
///     // Safe to split recording here
/// }
/// ```
public final class SileroVADStream {

    // MARK: - Public Properties

    /// The underlying VAD instance.
    public let vad: SileroVAD

    /// Number of consecutive frames classified as silence.
    public private(set) var consecutiveSilenceFrames: Int = 0

    /// Most recent speech probability from the last `process()` call.
    public private(set) var lastProbability: Float = 0

    // MARK: - Initialization

    /// Create a streaming VAD wrapper.
    ///
    /// - Parameter vad: A `SileroVAD` instance to use for inference.
    public init(vad: SileroVAD) {
        self.vad = vad
    }

    // MARK: - Public API

    /// Result of a streaming VAD process call.
    public struct StreamResult {
        /// Speech probability for this frame (0.0–1.0).
        public let probability: Float

        /// Whether silence has been sustained for the required number of frames.
        public let isSustainedSilence: Bool

        /// Number of consecutive silence frames so far.
        public let consecutiveSilenceFrames: Int
    }

    /// Process a chunk and check for sustained silence.
    ///
    /// - Parameters:
    ///   - samples: 512 Float samples at 16kHz.
    ///   - threshold: Speech probability below this is classified as silence (default: 0.3).
    ///   - requiredFrames: Number of consecutive silent frames required to trigger
    ///     `isSustainedSilence` (default: 16 frames = ~512ms at 32ms/frame).
    /// - Returns: A `StreamResult` with the probability and silence status.
    public func process(
        _ samples: [Float],
        threshold: Float = 0.3,
        requiredFrames: Int = 16
    ) throws -> StreamResult {
        let prob = try vad.process(samples)
        lastProbability = prob

        if prob < threshold {
            consecutiveSilenceFrames += 1
        } else {
            consecutiveSilenceFrames = 0
        }

        return StreamResult(
            probability: prob,
            isSustainedSilence: consecutiveSilenceFrames >= requiredFrames,
            consecutiveSilenceFrames: consecutiveSilenceFrames
        )
    }

    /// Reset silence counter. Call when starting a new detection window
    /// (e.g., after a chunk split).
    public func reset() {
        consecutiveSilenceFrames = 0
        lastProbability = 0
    }
}
