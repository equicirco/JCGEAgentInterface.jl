# Model Development

The agent interface is designed to help users develop CGE models with JCGE
without replacing the modeler's responsibility for theoretical structure,
calibration, closure choices, and scenario design.

## Recommended Workflow

1. Define the model scope: regions, commodities, activities, factors,
   institutions, policy instruments, and closure assumptions.
2. Select, cache, normalize, and validate source tables where needed.
3. Prepare calibration accounts, normally a SAM or equivalent account table.
4. Load calibration values and parameter-exploration values from explicit data.
5. Assemble the model from `JCGEBlocks` components.
6. Choose the mathematical formulation: equality equilibrium, inequality-constrained equilibrium, MCP/complementarity, or optimization-style representation.
7. Choose a solver route consistent with that formulation.
8. Solve the calibrated reference model.
9. Render blocks, symbols, and equations from the implemented model.
10. Validate the solved context and inspect residuals.
11. Run comparable scenarios or parameter experiments.
12. Export results through `JCGEOutput`.

## Block Discovery

Use `jcge_list_blocks` or the Julia action `:list_blocks` to inspect the block
catalog. Use `jcge_describe_block` or `:describe_block` to retrieve one entry.

The catalog groups blocks by role:

- production,
- factors,
- households,
- markets and prices,
- government and investment,
- trade and regions,
- closure and analysis.
- auxiliary quantities.

## Source Data and Examples

Use `jcge_import_data_guide` to discover the released `JCGEImportData`
support for BEA, Eurostat, FIGARO, and OECD tables. It can retrieve, normalize,
and validate source tables, but it deliberately does not determine a model's
aggregation, account mapping, SAM closure, or behavioral assumptions.

Use `jcge_list_examples` to discover installed `JCGEExamples` reference
implementations. Their data conventions, closures, and scenarios remain
example-specific and must be assessed before reuse.

## Comparability

Agents should preserve comparability across scenarios. In practice this means:

- keep model structure fixed unless the comparison explicitly concerns model variants,
- define zero-policy references for each policy family,
- load all calibration values and investigated parameter values from explicit data,
- use common output metrics across scenarios,
- regenerate equation listings from the implemented model through `JCGEOutput`.

## Formulation Guidance

Use `jcge_formulation_guide` before solving when the model may need more than a
binding equality system. The guide distinguishes:

- equality systems for standard calibrated equilibria,
- inequalities for explicit bounds, thresholds, or capacity restrictions,
- MCP/complementarity when an equation should bind only when an associated
  variable is active,
- optimization-style representations when the objective is part of the theory.

Use `jcge_solver_guide` to connect those choices to solver routes and
diagnostics.

## Calibration Guidance

Use `jcge_calibration_guide` to inspect what `JCGECalibrate` supports today:

- canonical CSV inputs,
- SAM loading,
- labeled vectors and matrices,
- starting-value computation,
- standard calibration parameter helpers,
- elasticity conversions.

Model-specific calibration logic should remain in the model package until it is
general enough to move into `JCGECalibrate`.

## Registered-Model Workflow

For a model that has adopted the agent interface contract, use the operational
workflow below. It keeps model code and economic choices with the model owner,
while making declared operations available to an agent.

1. Call `jcge_list_models`, then `jcge_load_model`.
2. Call `jcge_model_status` to inspect compatibility and available operations.
3. If the model declares calibration, call `jcge_calibrate_model` with its
   required structured inputs, then `jcge_check_calibration` when available.
4. Run a declared reference or policy study through `jcge_run_scenario` or
   `jcge_run_experiment`.
5. Solve a `RunSpec` through `jcge_solve` where the model workflow requires a
   separate solve, then use `jcge_validate_model`.
6. Request model-defined metrics through `jcge_run_reporter` and retrieve the
   ordered study record with `jcge_provenance`.

The agent must not infer calibration assumptions, scenario names, or indicators.
Those are declared by the model adapter.

## Reporting Guidance

Use `jcge_reporting_guide` to align scientific reporting with generated outputs.
The intended flow is to describe the model conceptually in the paper, and to use
`JCGEOutput` for generated equations, symbol tables, result tables, solver
metadata, physical satellite outputs, and reproducibility artifacts. Compact
equation mappings and physical anchors remain model-owned declarations.
