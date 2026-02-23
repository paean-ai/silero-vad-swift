# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### 1. Do NOT create a public GitHub issue

Security vulnerabilities should not be disclosed publicly until they have been addressed.

### 2. Email us directly

Send details to: **security@paean.ai**

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (optional)

### 3. Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Depends on severity and complexity

## Security Considerations

### Model Files

The CoreML models bundled in this package are converted from the open-source
[Silero VAD](https://github.com/snakers4/silero-vad) project. They run entirely
on-device and do not transmit any audio data.

### Privacy

This package:
- Does **not** collect any data
- Does **not** make any network requests
- Processes audio **entirely on-device**
- Does **not** store or cache any audio data

## Acknowledgments

We appreciate responsible disclosure and will acknowledge security researchers who report valid vulnerabilities.
