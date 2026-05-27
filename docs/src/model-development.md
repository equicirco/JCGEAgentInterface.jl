# Model Development

The agent interface is designed to help users develop CGE models with JCGE
without replacing the modeler's responsibility for theoretical structure,
calibration, closure choices, and scenario design.

## Recommended Workflow

1. Define the model scope: regions, commodities, activities, factors,
   institutions, policy instruments, and closure assumptions.
2. Prepare calibration accounts, normally a SAM or equivalent account table.
3. Load calibration values and parameter-exploration values from explicit data.
4. Assemble the model from `JCGEBlocks` components.
5. Choose the mathematical formulation: equality equilibrium, inequality-constrained equilibrium, MCP/complementarity, or optimization-style representation.
6. Choose a solver route consistent with that formulation.
7. Solve the calibrated reference model.
8. Render blocks, symbols, and equations from the implemented model.
9. Validate the solved context and inspect residuals.
10. Run comparable scenarios or parameter experiments.
11. Export results through `JCGEOutput`.

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

## Reporting Guidance

Use `jcge_reporting_guide` to align scientific reporting with generated outputs.
The intended flow is to describe the model conceptually in the paper, and to use
`JCGEOutput` for generated equations, symbol tables, result tables, solver
metadata, and reproducibility artifacts.
