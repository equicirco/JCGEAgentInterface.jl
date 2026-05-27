# Agent Services

`JCGEAgentInterface` provides a service layer over the JCGE package stack. The
services are available through the Julia action API and through the MCP stdio
server.

## Discovery Services

Discovery services help an agent or user inspect what the active JCGE
environment can do.

| Service | Actions and MCP tools | What it provides |
| --- | --- | --- |
| Package capabilities | `:capabilities`, `jcge_capabilities` | JCGE package versions, equation-expression support, runtime features, output formats, and update policy. |
| Package status | `:package_status`, `jcge_package_status` | Installed and loaded JCGE package versions in the active Julia environment. |
| Block catalog | `:list_blocks`, `jcge_list_blocks` | Reusable `JCGEBlocks` helpers grouped by production, factors, households, markets, government, trade, and closure/analysis roles. |
| Block description | `:describe_block`, `jcge_describe_block` | Purpose, helper name, block type, main inputs, and notes for one block entry. |

## Modeling Guidance Services

Guidance services are meant to help modelers use the JCGE approach consistently.
They do not replace the theoretical modeling decision.

| Service | Actions and MCP tools | What it provides |
| --- | --- | --- |
| Model-development guide | `:modeling_guide`, `jcge_modeling_guide` | Recommended workflow from scope, SAM/calibration, blocks, formulation, solving, experiments, and output. |
| Formulation guide | `:formulation_guide`, `jcge_formulation_guide` | Guidance on equality systems, inequality-constrained systems, MCP/complementarity, and optimization-style formulations. |
| Solver guide | `:solver_guide`, `jcge_solver_guide` | Solver choice and diagnostics for `Ipopt`, `PATHSolver`, and user-provided JuMP optimizers. |
| Calibration guide | `:calibration_guide`, `jcge_calibration_guide` | Current `JCGECalibrate` support for canonical CSV inputs, SAM loading, labeled containers, starting values, calibration parameters, and elasticity helpers. |
| Reporting guide | `:reporting_guide`, `jcge_reporting_guide` | How to use `JCGEOutput` for generated equations, block listings, symbol tables, result exports, solver metadata, and reproducibility artifacts. |

## Model Interaction Services

Model interaction services operate on models registered in an `AgentContext`.

| Service | Actions and MCP tools | What it provides |
| --- | --- | --- |
| List models | `:list_packages`, `jcge_list_models` | Registered model names and package status. The action name is kept for backward compatibility. |
| Load model | `:load_model`, `jcge_load_model` | Select a registered model by name and store it as the active model. |
| Solve model | `:solve`, `jcge_solve` | Solve the active or named `RunSpec` with an optional optimizer. |
| Validate model | `:validate_model`, `jcge_validate_model` | Run `JCGERuntime.validate_model` on the last solved context. |

## Reporting Services

Reporting services expose implemented model structure and solved results.

| Service | Actions and MCP tools | What it provides |
| --- | --- | --- |
| Render model | `:render_model`, `jcge_render_model` | Render equations, blocks, or symbols in markdown, LaTeX, or plain text. |
| Render equations | `:render_equations` | Backward-compatible equation-rendering action. |
| Export results | `:export_results`, `jcge_export_results` | Return tidy results collected from the last solved model. |

## Environment Maintenance Services

| Service | Actions and MCP tools | What it provides |
| --- | --- | --- |
| Update packages | `:update_packages`, `jcge_update_packages` | Dry-run or apply `Pkg.update` for selected released JCGE packages in the active Julia environment. |

`jcge_update_packages` is conservative by default. It reports the planned update
without changing the environment unless `apply=true` is passed.

## MCP Runtime Services

The package can run as a standard stdio MCP server:

```julia
using JCGEAgentInterface
serve(transport=:mcp_stdio)
```

The repository also provides:

- `Dockerfile`,
- `server.json`,
- `.github/workflows/publish-mcp.yml`.

The release workflow builds the Docker image, pushes it to GitHub Container
Registry, updates `server.json`, and publishes the MCP server metadata to the
official MCP Registry.

## Current Limits

The agent interface is intentionally a service layer, not an automatic CGE model
generator.

Current limits:

- It does not automatically create complete CGE models.
- It does not fetch arbitrary external data.
- It does not decide the correct economic theory, closure, formulation, or
  calibration assumptions for the user.
- It solves only models that have been registered in the running `AgentContext`.
- A plain Docker/MCP container starts with no user models registered.
- In plain Docker/MCP mode, discovery and guidance tools work immediately, but
  solving requires a host Julia process or package extension that registers
  models in the server context.
- `JCGECalibrate` provides currently available SAM and canonical-input helpers;
  model-specific calibration formulas should remain in the model package until
  they are general enough to move into `JCGECalibrate`.

These limits are deliberate. They keep the agent interface aligned with JCGE's
model-as-code approach: models are explicit Julia packages or scripts, while the
agent interface helps discover, validate, solve, render, and document them.
