# Contributing to SileroVAD Swift

Thank you for your interest in contributing! This guide will help you get started.

## Development Setup

### Prerequisites

- Xcode 15.0+ or Swift 5.9+
- macOS 13+ (for development)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/paean-ai/silero-vad-swift.git
cd silero-vad-swift

# Build the package
swift build

# Run tests
swift test
```

### Xcode

Open `Package.swift` directly in Xcode for IDE support:

```bash
open Package.swift
```

## Code Style

- Use Swift naming conventions
- Follow existing code patterns
- Add documentation comments (`///`) for all public APIs
- Keep the package lightweight — avoid adding dependencies

## Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature`
3. **Commit** your changes with clear messages
4. **Test** your changes: `swift test`
5. **Push** to your fork and create a Pull Request

### PR Guidelines

- Keep PRs focused on a single feature or fix
- Update documentation if needed
- Add tests for new functionality
- Ensure `swift build` and `swift test` pass

## Reporting Issues

When reporting bugs, please include:

- Swift version (`swift --version`)
- Target platform (iOS version, macOS version)
- Steps to reproduce
- Expected vs actual behavior

## Security

For security vulnerabilities, please see [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
