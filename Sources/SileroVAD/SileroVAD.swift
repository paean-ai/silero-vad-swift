import CoreML
import Foundation

/// Lightweight Silero VAD v6 wrapper using a single unified Apple CoreML model.
///
/// Processes 512-sample audio chunks at 16kHz and returns a speech probability
/// between 0.0 (silence) and 1.0 (speech). The model performs STFT, encoding,
/// and RNN decoding internally — no external state management needed.
///
/// ## Usage
///
/// ```swift
/// let vad = try SileroVAD()
/// let prob = try vad.process(audioChunk) // 512 Float samples at 16kHz
/// if prob > 0.5 { print("Speech detected") }
/// ```
///
/// ## Thread Safety
///
/// `SileroVAD` maintains internal model state and is **not** thread-safe.
/// Create separate instances for concurrent use or synchronize access externally.
public final class SileroVAD {

    // MARK: - Public Constants

    /// Expected sample rate in Hz.
    public static let sampleRate: Int = 16000

    /// Number of samples per chunk (32ms at 16kHz).
    public static let chunkSize: Int = 512

    // MARK: - Private Properties

    private let model: MLModel

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
                    // Fallback: look for the model inside the copied Resources directory
                    let url = resourceURL.appendingPathComponent("Resources/silero_vad.mlmodelc")
                    return FileManager.default.fileExists(atPath: url.path) ? url : nil
                }()
        else {
            throw SileroVADError.modelNotFound
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all  // Prefer Apple Neural Engine when available

        model = try MLModel(contentsOf: modelURL, configuration: config)
    }

    // MARK: - Public API

    /// Process a single audio chunk and return the speech probability.
    ///
    /// - Parameter samples: Exactly 512 Float samples at 16kHz, mono.
    /// - Returns: Speech probability between 0.0 (silence/noise) and 1.0 (speech).
    /// - Throws: `SileroVADError` if the input size is wrong or inference fails.
    public func process(_ samples: [Float]) throws -> Float {
        guard samples.count == Self.chunkSize else {
            throw SileroVADError.invalidChunkSize(expected: Self.chunkSize, got: samples.count)
        }

        // Prepare input: shape [1, 512]
        let inputArray = try Self.floatsToMultiArray(samples, shape: [1, NSNumber(value: Self.chunkSize)])

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "audio_chunk": MLFeatureValue(multiArray: inputArray)
        ])

        let result = try model.prediction(from: provider)

        guard let output = result.featureValue(for: "vad_probability")?.multiArrayValue else {
            throw SileroVADError.inferenceError
        }

        return output[0].floatValue
    }

    /// Convenience: check if a chunk contains speech.
    ///
    /// - Parameters:
    ///   - samples: 512 Float samples at 16kHz.
    ///   - threshold: Probability above which to classify as speech (default: 0.5).
    /// - Returns: `true` if the chunk is classified as speech.
    public func isSpeech(_ samples: [Float], threshold: Float = 0.5) throws -> Bool {
        return try process(samples) > threshold
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
            return "SileroVAD: CoreML inference failed to produce vad_probability output."
        }
    }
}
