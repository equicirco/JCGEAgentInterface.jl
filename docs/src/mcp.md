# MCP Server

The package ships a standard stdio MCP server over the JCGE agent actions.

## Runtime

```julia
using JCGEAgentInterface
serve(transport=:mcp_stdio)
```

The server supports:

- `initialize`
- `notifications/initialized`
- `ping`
- `tools/list`
- `tools/call`

## Tool Surface

The MCP tools are:

| MCP tool | Action | Purpose |
| --- | --- | --- |
| `jcge_capabilities` | `:capabilities` | Discover JCGE packages, interfaces, output formats, and runtime features. |
| `jcge_list_blocks` | `:list_blocks` | List reusable block helpers grouped by CGE model component. |
| `jcge_describe_block` | `:describe_block` | Describe one block helper or block type. |
| `jcge_modeling_guide` | `:modeling_guide` | Return structured guidance for building CGE models with JCGE. |
| `jcge_formulation_guide` | `:formulation_guide` | Guide equality, inequality, MCP/complementarity, and optimization-style formulations. |
| `jcge_solver_guide` | `:solver_guide` | Guide solver choice and diagnostics for different formulations. |
| `jcge_calibration_guide` | `:calibration_guide` | Guide currently available JCGECalibrate inputs, SAM helpers, and calibration workflow. |
| `jcge_reporting_guide` | `:reporting_guide` | Guide generated equation, symbol, result, and reproducibility reporting. |
| `jcge_package_status` | `:package_status` | Report installed and loaded JCGE package versions. |
| `jcge_update_packages` | `:update_packages` | Dry-run or apply `Pkg.update` for released JCGE packages. |
| `jcge_list_models` | `:list_packages` | List registered models, capabilities, and compatibility. |
| `jcge_load_model` | `:load_model` | Load a registered model and return its declared contract. |
| `jcge_model_status` | `:model_status` | Read compatibility, lifecycle state, and safe next actions without running a model. |
| `jcge_calibrate_model` | `:calibrate_model` | Run the selected model's declared calibration workflow. |
| `jcge_check_calibration` | `:check_calibration` | Run the selected model's declared calibration diagnostic. |
| `jcge_run_scenario` | `:run_scenario` | Run a selected model-owned named scenario. |
| `jcge_run_experiment` | `:run_experiment` | Run a selected model-owned named experiment. |
| `jcge_solve` | `:solve` | Solve a loaded or named `RunSpec`. |
| `jcge_validate_model` | `:validate_model` | Validate the last solved context. |
| `jcge_run_reporter` | `:run_reporter` | Run a named model-owned reporter on a study or solve result. |
| `jcge_provenance` | `:provenance` | Return session-scoped study provenance records. |
| `jcge_render_model` | `:render_model` | Render equations, blocks, or symbols. |
| `jcge_export_results` | `:export_results` | Return tidy results from the last solve. |

`jcge_calibrate_model`, `jcge_check_calibration`, `jcge_run_scenario`,
`jcge_run_experiment`, and `jcge_run_reporter` invoke only callbacks explicitly
registered by the model owner. MCP clients provide structured values and choose
declared names; they cannot send Julia code or edit model equations.

## Package Updates

`jcge_update_packages` is conservative by default. Without `apply=true`, it
reports the packages that would be updated and the equivalent Julia command.
With `apply=true`, it calls `Pkg.update` for the selected released JCGE packages
in the active Julia environment.

## Docker and Registry Metadata

The repository contains:

- `Dockerfile`
- `.dockerignore`
- `server.json`
- `.github/workflows/publish-mcp.yml`

The release workflow builds and pushes:

```text
ghcr.io/equicirco/jcge-agentinterface-mcp:<release-version>
```

and publishes `server.json` to the MCP Registry. The image declares the required
MCP ownership label:

```text
io.modelcontextprotocol.server.name=io.github.equicirco/JCGEAgentInterface.jl
```
