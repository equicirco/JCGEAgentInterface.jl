# Model Integration

`JCGEAgentInterface` is a service layer. A model package remains responsible
for its equations, data, calibration choices, closures, studies, and reported
metrics. The optional adapter contract lets that model declare the operations an
MCP client may request.

## Legacy and Adapter Registration

Existing models continue to work with the compact registration form:

```julia
register_model!(ctx, "my-model", build_my_model)
```

This supports selecting and solving the model. To expose calibration, named
studies, indicators, and model-defined reporters, register a `ModelAdapter`.

```julia
using JCGEAgentInterface

adapter = ModelAdapter(
    "my-model",
    build_my_model;
    description = "Short description of the model.",
    version = "1.0.0",
    compatibility = Dict("JCGECore" => "0.1"),
    calibration_inputs = [
        CalibrationInput("sam"; description = "Balanced social accounting matrix."),
    ],
    calibrate = calibrate_my_model,
    check_calibration = check_my_calibration,
    scenarios = [
        WorkflowAdapter("reference", run_reference_scenario),
        WorkflowAdapter("policy", run_policy_scenario;
            parameters = Dict("tax_change" => Dict("type" => "number", "required" => true))),
    ],
    experiments = [
        WorkflowAdapter("elasticity-grid", run_elasticity_grid;
            parameters = Dict("sigma" => Dict("type" => "number", "required" => true))),
    ],
    indicators = [
        ResultIndicator("real_gdp"; description = "Real GDP index.", unit = "index"),
    ],
    reporters = Dict("summary" => report_summary),
)

register_model!(ctx, adapter)
```

The model package or server-startup script owns this code. `JCGEAgentInterface`
does not hard-code application models or modify their equations.

## Callback Contract

| Callback | Model-owned responsibility | MCP behavior |
| --- | --- | --- |
| `build_my_model()` or `build_my_model(calibration)` | Return a `JCGECore.RunSpec`; optionally consume the calibration artifact. | `jcge_solve` invokes the constructor. |
| `calibrate_my_model(inputs)` | Convert declared structured inputs into a calibration artifact. | `jcge_calibrate_model` checks required inputs, retains the artifact in the server session, and never exposes it as arbitrary code. |
| `check_my_calibration(artifact)` | Return structured diagnostics. | `jcge_check_calibration` returns the diagnostics. |
| `run_*_scenario(state, parameters)` | Run one declared scenario and return structured study output. | `jcge_run_scenario` validates declared parameters and supplies read-only state. |
| `run_*_grid(state, parameters)` | Run one declared experiment and return structured output. | `jcge_run_experiment` validates declared parameters and supplies read-only state. |
| `report_summary(result)` | Derive structured model metrics from a workflow or solved result. | `jcge_run_reporter` returns the report with declared indicator definitions. |

Scenario and experiment callbacks receive a `WorkflowState` containing the
model name, calibration artifact when available, latest specification, and
latest solved result for that same model. They should return JSON-compatible
data: strings, numbers, booleans, nulls, arrays, and string-keyed maps.

## Study Lifecycle and Provenance

Use `jcge_model_status` before requesting an operation. It reports compatibility,
current calibration/study/solve/report state, and safe next tools without
running a callback.

Every successful lifecycle operation appends a session record accessible through
`jcge_provenance`. Records include ordered IDs, timestamps, model version and
compatibility, JCGE package versions, and the structured inputs or parameters
provided to the operation. The server does not write these records to disk; the
MCP client retrieves and persists them deliberately.

Because records include the structured calibration inputs and study parameters,
do not send secrets through an MCP server unless its hosting environment and
client are trusted.
