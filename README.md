<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/src/assets/jcge_agentinterface_logo_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/src/assets/jcge_agentinterface_logo_light.png">
  <img alt="JCGE AgentInterface logo" src="docs/src/assets/jcge_agentinterface_logo_light.png" height="150">
</picture>

# JCGEAgentInterface

## What is a CGE?
A Computable General Equilibrium (CGE) model is a quantitative economic model that represents an economy as interconnected markets for goods and services, factors of production, institutions, and the rest of the world. It is calibrated with data (typically a Social Accounting Matrix) and solved numerically as a system of nonlinear equations until equilibrium conditions (zero-profit, market-clearing, and income-balance) hold within tolerance.

## What is JCGE?
[JCGE](https://jcge.org) is a block-based CGE modeling and execution framework in Julia. It defines a shared RunSpec structure and reusable blocks so models can be assembled, validated, solved, and compared consistently across packages.

## What is this package?
MCP-compatible interface layer for agents that need to load, solve, and inspect

[JCGE](https://jcge.org) models. This package provides a schema, request routing, and handler stubs
that can be wired into a transport layer.

## Stdio server

`serve()` reads JSON requests from stdin and writes JSON responses to stdout.

## How to cite

If you use the [JCGE](https://jcge.org) framework, please cite:

Boero, R. *JCGE - Julia Computable General Equilibrium Framework* [software], 2026.
DOI: 10.5281/zenodo.18282436
URL: https://JCGE.org

```bibtex
@software{boero_jcge_2026,
  title  = {JCGE - Julia Computable General Equilibrium Framework},
  author = {Boero, Riccardo},
  year   = {2026},
  doi    = {10.5281/zenodo.18282436},
  url    = {https://JCGE.org}
}
```

If you use this package, please cite:

Boero, R. *JCGEAgentInterface.jl - MCP-compatible agent interface for JCGE tooling.* [software], 2026.
DOI: not yet assigned
URL: https://JCGEAgentInterface.JCGE.org
SourceCode: https://github.com/equicirco/JCGEAgentInterface.jl

```bibtex
@software{boero_jcgeagentinterface_2026,
  title  = {JCGEAgentInterface.jl - MCP-compatible agent interface for JCGE tooling.},
  author = {Boero, Riccardo},
  year   = {2026},
  doi    = {not yet assigned},
  url    = {https://JCGEAgentInterface.JCGE.org}
}
```

If you use a specific tagged release, please cite the version DOI assigned on Zenodo for that release (preferred for exact reproducibility).
