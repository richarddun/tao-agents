# Changelog

## 0.1.0 — Experimental Release

- Initial package structure following TAO specification v0.1
- Core taskrail: 8-step privacy audit (fingerprint → enumerate → probe → classify → approval gate → apply → verify → report)
- Induction taskrail: 7-step onboarding (verify platform → check dependencies → explain model → dry run → generate config → readiness check → complete)
- Surface catalog: 40+ known telemetry surfaces across Windows 10/11, macOS 13-15, Linux (Ubuntu/Fedora/Debian), Chrome, Firefox, Edge, Safari, Brave
- Fingerprint script: OS/browser/tool detection with JSON output
- Core SOP: execution methodology for each audit step with error recovery guidance
- agent.yaml: Complete TAO manifest with authority boundaries, compatibility matrix, lifecycle definitions
- SYSTEM.md: Full operating doctrine with non-negotiable boundaries and failure modes
- README: User-facing documentation with quick start, platform support, and safety notes
- Known gaps:
  - Windows: closed-source telemetry channels that cannot be verified (probe shows "disabled" but kernel-level collection may continue)
  - macOS: System Integrity Protection (SIP) prevents modifying some OS-level telemetry paths
  - Linux: Distribution fragmentation means not all package telemetry channels are catalogued
  - All platforms: Browser fingerprinting (canvas, WebGL, font enumeration) is a privacy surface not yet addressed
  - All platforms: Application-level telemetry for software beyond browsers is minimal in v0.1
  - Network surfaces: DNS-over-HTTPS configuration is recommended but not automated (requires user input on resolver choice)