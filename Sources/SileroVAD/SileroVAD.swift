// Copyright (c) 2026 Pæan™
// Licensed under the MIT License. See LICENSE for details.

import CoreML
import Foundation

/// Lightweight Silero VAD v6.0.0 wrapper using Apple CoreML.
///
/// Processes 576-sample audio chunks at 16kHz and returns a speech probability
/// between 0.0 (silence) and 1.0 (speech). Based on the official Silero VAD
/// unified model with explicit LSTM state management for maximum accuracy.
///
/// ## Usage
///
/// ```swift
/// let vad = try SileroVAD()
/// let prob = try vad.process(audioChunk) // 576 Float samples at 16kHz
/// if prob > 0.5 { print("Speech detected") }
/// ```
///
/// ## Thread Safety
///
/// `SileroVAD` maintains internal LSTM state and is **not** thread-safe.
/// Create separate instances for concurrent use or synchronize access externally.
public final class SileroVAD {

    // MARK: - Public Constants

    /// Expected sample rate in Hz.
    public static let sampleRate: Int = 16000

    /// Number of samples per chunk (36ms at 16kHz).
    public static let chunkSize: Int = 576

    // MARK: - Private Properties

    private let model: MLModel

    /// LSTM hidden state — carried across `process()` calls.
    private var hiddenState: MLMultiArray

    /// LSTM cell state — carried across `process()` calls.
    private var cellState: MLMultiArray

    /// Shape for LSTM states: [1, 128].
    private static let stateShape: [NSNumber] = [1, 128]

    // MARK: - Initialization

    /// Create a new SileroVAD instance, loading the CoreML model from the package bundle.
    ///
    /// - Throws: `SileroVADError.modelNotFound` if the model file is missing,
    ///   or a CoreML error if loading fails.
    public init() throws {
        let bundle = Bundle.module

        guard let resourceURL = bundle.resourceURL,
              let modelURL = bundle.url(forResource: "Resources/silero_vad", withExtension: "mlmodelc")
                ?? bundle.url(forResource: "silero_vad", withExtension: "mlmodelc")
                ?? {
                    let url = resourceURL.appendingPathComponent("Resources/silero_vad.mlmodelc")
                    return FileManager.default.fileExists(atPath: url.path) ? url : nil
                }()
        else {
            throw SileroVADError.modelNotFound
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all  // Prefer Apple Neural Engine when available

        model = try MLModel(contentsOf: modelURL, configuration: config)

        // Initialize LSTM states to zeros
        hiddenState = try MLMultiArray(shape: Self.stateShape, dataType: .float32)
        cellState = try MLMultiArray(shape: Self.stateShape, dataType: .float32)
    }

    // MARK: - Public API

    /// Process a single audio chunk and return the speech probability.
    ///
    /// The model carries LSTM state between calls, providing temporal context
    /// for more accurate voice activity detection across consecutive chunks.
    ///
    /// - Parameter samples: Exactly 576 Float samples at 16kHz, mono.
    /// - Returns: Speech probability between 0.0 (silence/noise) and 1.0 (speech).
    /// - Throws: `SileroVADError` if the input size is wrong or inference fails.
    public func process(_ samples: [Float]) throws -> Float {
        guard samples.count == Self.chunkSize else {
            throw SileroVADError.invalidChunkSize(expected: Self.chunkSize, got: samples.count)
        }

        // Prepare audio input: shape [1, 576]
        let audioInput = try Self.floatsToMultiArray(
            samples, shape: [1, NSNumber(value: Self.chunkSize)]
        )

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "audio_input": MLFeatureValue(multiArray: audioInput),
            "hidden_state": MLFeatureValue(multiArray: hiddenState),
            "cell_state": MLFeatureValue(multiArray: cellState),
        ])

        let result = try model.prediction(from: provider)

        // Update LSTM state for next call
        if let newH = result.featureValue(for: "new_hidden_state")?.multiArrayValue {
            hiddenState = newH
        }
        if let newC = result.featureValue(for: "new_cell_state")?.multiArrayValue {
            cellState = newC
        }

        guard let output = result.featureValue(for: "vad_output")?.multiArrayValue else {
            throw SileroVADError.inferenceError
        }

        return output[0].floatValue
    }

    /// Convenience: check if a chunk contains speech.
    ///
    /// - Parameters:
    ///   - samples: 576 Float samples at 16kHz.
    ///   - threshold: Probability above which to classify as speech (default: 0.5).
    /// - Returns: `true` if the chunk is classified as speech.
    public func isSpeech(_ samples: [Float], threshold: Float = 0.5) throws -> Bool {
        return try process(samples) > threshold
    }

    /// Reset LSTM state. Call when starting a new audio stream.
    ///
    /// This clears the temporal context built up from previous chunks.
    public func reset() {
        hiddenState = (try? MLMultiArray(shape: Self.stateShape, dataType: .float32)) ?? hiddenState
        cellState = (try? MLMultiArray(shape: Self.stateShape, dataType: .float32)) ?? cellState
    }

    // MARK: - Helpers

    /// Convert a Float array to MLMultiArray with given shape.
    private static func floatsToMultiArray(_ values: [Float], shape: [NSNumber]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape, dataType: .float32)
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: values.count)
        for i in 0..<values.count {
            pointer[i] = values[i]
        }
        return array
    }
}

// MARK: - Errors

/// Errors thrown by `SileroVAD`.
public enum SileroVADError: LocalizedError {
    /// CoreML model file not found in the package bundle.
    case modelNotFound

    /// Input chunk has wrong number of samples.
    case invalidChunkSize(expected: Int, got: Int)

    /// CoreML inference failed.
    case inferenceError

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "SileroVAD: CoreML model file (silero_vad.mlmodelc) not found in bundle."
        case .invalidChunkSize(let expected, let got):
            return "SileroVAD: Expected \(expected) samples, got \(got)."
        case .inferenceError:
            return "SileroVAD: CoreML inference failed to produce vad_output."
        }
    }
}
