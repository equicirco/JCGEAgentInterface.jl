# JCGEAgentInterface Changelog
All notable changes to this project will be documented in this file.
Releases use semantic versioning as in 'MAJOR.MINOR.PATCH'.

## Change entries
Added: For new features that have been added.
Changed: For changes in existing functionality.
Deprecated: For once-stable features removed in upcoming releases.
Removed: For features removed in this release.
Fixed: For any bug fixes.
Security: For vulnerabilities.

## [0.1.0] - unreleased
### Added
- MCP-style request/response schema with validation helpers.
- Handler registry and request dispatch utilities.
- AgentContext registry for model references, last spec, and last result.
- Server entry point with stdio, HTTP, and WebSocket transports.
- Built-in actions for listing models, loading models, solving, rendering equations, and exporting results.
- Basic tests and documentation scaffolding for the agent interface.
