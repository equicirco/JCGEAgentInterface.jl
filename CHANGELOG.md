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

## [0.1.1] - 2026-05-27
### Added
- Standard MCP JSON-RPC stdio transport with `initialize`, `tools/list`, `tools/call`, and `ping` support.
- MCP tools for JCGE capability discovery, block discovery, block descriptions, model-development guidance, package status, package updates, model loading, solving, validation, rendering, and result export.
- JCGEBlocks dependency for live block catalog discovery and CGE model-building guidance.
- JCGECalibrate dependency and calibration guidance for canonical CSV inputs, SAM loading, starting values, calibration parameters, labeled containers, and currently available helpers.
- Formulation, solver, and reporting guidance tools covering equality systems, inequalities, MCP/complementarity formulations, solver selection, diagnostics, and generated equation reporting.
- Package-status and dry-run/apply package-update actions for released JCGE packages in the active Julia environment.
- Dockerfile, MCP `server.json`, and GitHub Actions workflow for GHCR image publication and MCP Registry publication on future version tags.

### Changed
- `list_packages` now reports both registered agent models and installed/loaded JCGE package versions.
- `render_equations` now delegates to the broader `render_model` action while preserving the existing action name.
- Documentation now describes the agent workflow, MCP server, block discovery, Docker image shape, and MCP registry release process.

## [0.1.0] - 2026-01-22
### Added
- MCP-style request/response schema with validation helpers.
- Handler registry and request dispatch utilities.
- AgentContext registry for model references, last spec, and last result.
- Server entry point with stdio, HTTP, and WebSocket transports.
- Built-in actions for listing models, loading models, solving, rendering equations, and exporting results.
- Basic tests and documentation scaffolding for the agent interface.
