# SileroVAD Swift

> Lightweight, on-device Voice Activity Detection for iOS & macOS — powered by Silero VAD v6 CoreML models.

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue?style=flat-square" alt="platform" />
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange?style=flat-square" alt="swift" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="license" />
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" alt="no deps" />
</p>

## Features

- **~2MB total** — CoreML models bundled, no downloads at runtime
- **Zero dependencies** — pure Swift + Apple CoreML framework
- **< 2ms inference** on Apple Neural Engine (ANE)
- **Streaming API** — built-in sustained silence detection for real-time audio
- **16kHz / 576-sample** chunks (36ms per frame)
- **Explicit LSTM state** — full-fidelity Silero VAD v6.0.0 with temporal context

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/paean-ai/silero-vad-swift.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the URL.

## Quick Start

### Basic Usage

```swift
import SileroVAD

let vad = try SileroVAD()

// Process 576 samples at 16kHz (36ms chunk)
let audioChunk: [Float] = // ... your audio samples
let probability = try vad.process(audioChunk)

if probability > 0.5 {
    print("Speech detected")
}

// Reset state when starting a new audio stream
vad.reset()
```

### Streaming with Silence Detection

```swift
import SileroVAD

let vad = try SileroVAD()
let stream = SileroVADStream(vad: vad)

// In your audio callback, feed 576-sample chunks:
for chunk in audioChunks {
    let result = try stream.process(chunk, threshold: 0.3, requiredFrames: 16)
    
    if result.isSustainedSilence {
        print("Silence sustained for ~0.5s — safe to split recording")
    }
}
```

### Integration with AVAudioEngine

```swift
import AVFoundation
import SileroVAD

let engine = AVAudioEngine()
let inputNode = engine.inputNode
let vad = try SileroVAD()

// Install tap at 16kHz mono
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                           sampleRate: 16000, channels: 1, interleaved: false)!

inputNode.installTap(onBus: 0, bufferSize: 576, format: format) { buffer, _ in
    guard let data = buffer.floatChannelData?[0] else { return }
    let samples = Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
    
    // Process in 576-sample chunks
    var offset = 0
    while offset + 576 <= samples.count {
        let chunk = Array(samples[offset..<offset+576])
        if let prob = try? vad.process(chunk), prob > 0.5 {
            print("Speech at offset \(offset)")
        }
        offset += 576
    }
}

try engine.start()
```

## API Reference

### `SileroVAD`

| Method | Description |
|--------|-------------|
| `init()` | Load CoreML model from bundle |
| `process([Float]) -> Float` | Process 576 samples, returns speech probability (0.0–1.0) |
| `reset()` | Reset LSTM state for new audio stream |

### `SileroVADStream`

| Method | Description |
|--------|-------------|
| `init(vad:)` | Wrap a `SileroVAD` instance |
| `process(_:threshold:requiredFrames:)` | Returns `(probability, isSustainedSilence)` |
| `reset()` | Reset silence counter and VAD state |

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `SileroVAD.sampleRate` | 16000 | Expected sample rate (Hz) |
| `SileroVAD.chunkSize` | 576 | Samples per chunk (36ms) |

## Model Details

This package uses [Silero VAD v6.0.0](https://github.com/snakers4/silero-vad) converted to CoreML format. The unified model integrates:

1. **STFT** — Short-Time Fourier Transform preprocessing
2. **Encoder** — Feature extraction
3. **RNN Decoder** — Temporal classification with LSTM state

The original Silero VAD model is MIT-licensed by the Silero Team.

## Use Cases

- **Auto-chunking long recordings** — split at natural speech pauses
- **Wake-word pre-filtering** — skip silence before expensive ASR
- **Voice chat endpoints** — detect when the user stops speaking
- **Audio journaling** — segment recordings into speech segments

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Security

For security vulnerabilities, please see [SECURITY.md](SECURITY.md).

## License

MIT © [Paean AI](https://paean.ai)

### Acknowledgments

- [Silero VAD](https://github.com/snakers4/silero-vad) by the Silero Team (MIT License)
- CoreML model conversion based on techniques from [FluidInference/mobius](https://github.com/FluidInference/mobius)
