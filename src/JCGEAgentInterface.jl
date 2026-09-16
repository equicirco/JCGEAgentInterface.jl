"""
MCP-compatible interface layer for JCGE tooling.
"""
module JCGEAgentInterface

include("Schema.jl")
include("Handlers.jl")
include("Adapters.jl")
include("Context.jl")
include("Catalog.jl")
include("Server.jl")
include("Actions/list_packages.jl")
include("Actions/capabilities.jl")
include("Actions/list_blocks.jl")
include("Actions/describe_block.jl")
include("Actions/modeling_guide.jl")
include("Actions/formulation_guide.jl")
include("Actions/solver_guide.jl")
include("Actions/calibration_guide.jl")
include("Actions/reporting_guide.jl")
include("Actions/package_status.jl")
include("Actions/update_packages.jl")
include("Actions/load_model.jl")
include("Actions/calibrate_model.jl")
include("Actions/check_calibration.jl")
include("Actions/run_workflow.jl")
include("Actions/run_reporter.jl")
include("Actions/provenance.jl")
include("Actions/model_status.jl")
include("Actions/solve.jl")
include("Actions/render_model.jl")
include("Actions/render_equations.jl")
include("Actions/validate_model.jl")
include("Actions/export_results.jl")

using .Schema: ActionRequest, ActionResponse, request, response
using .Handlers: register_handler!, handle_request, default_handlers
using .Server: serve, MCPServer, handle_mcp_message
using .Adapters: CalibrationInput, WorkflowAdapter, ResultIndicator, ModelAdapter
using .Adapters: WorkflowState, adapter_summary, build_model, calibration_input_status
using .Adapters: calibration_diagnostics, workflow_parameter_status, run_workflow, run_reporter, transport_value, compatibility_status
using .Context: AgentContext, register_model!, model_names, model_adapter, active_model_adapter
using .Context: record_provenance!, provenance_records
using .Catalog: package_inventory, package_version_map, block_catalog, describe_block, capability_catalog, modeling_guide
using .Catalog: formulation_guide, solver_guide, calibration_guide, reporting_guide, mcp_tool_definitions
using .ListPackages
using .Capabilities
using .ListBlocks
using .DescribeBlock
using .ModelingGuide
using .FormulationGuide
using .SolverGuide
using .CalibrationGuide
using .ReportingGuide
using .PackageStatus
using .UpdatePackages
using .LoadModel
using .Solve
using .RenderEquations
using .RenderModel
using .ValidateModel
using .ExportResults

export ActionRequest, ActionResponse, request, response
export CalibrationInput, WorkflowAdapter, ResultIndicator, ModelAdapter
export WorkflowState, adapter_summary, build_model, calibration_input_status, calibration_diagnostics
export workflow_parameter_status, run_workflow, run_reporter, transport_value, compatibility_status
export AgentContext, register_model!, model_names, model_adapter, active_model_adapter
export record_provenance!, provenance_records
export register_handler!, handle_request, default_handlers
export serve, MCPServer, handle_mcp_message
export package_inventory, package_version_map, block_catalog, describe_block, capability_catalog, modeling_guide
export formulation_guide, solver_guide, calibration_guide, reporting_guide, mcp_tool_definitions

"""
Register the default action handlers.
"""
function __init__()
    register_handler!(:list_packages, ListPackages.handler)
    register_handler!(:capabilities, Capabilities.handler)
    register_handler!(:list_blocks, ListBlocks.handler)
    register_handler!(:describe_block, DescribeBlock.handler)
    register_handler!(:modeling_guide, ModelingGuide.handler)
    register_handler!(:formulation_guide, FormulationGuide.handler)
    register_handler!(:solver_guide, SolverGuide.handler)
    register_handler!(:calibration_guide, CalibrationGuide.handler)
    register_handler!(:reporting_guide, ReportingGuide.handler)
    register_handler!(:package_status, PackageStatus.handler)
    register_handler!(:update_packages, UpdatePackages.handler)
    register_handler!(:load_model, LoadModel.handler)
    register_handler!(:calibrate_model, CalibrateModel.handler)
    register_handler!(:check_calibration, CheckCalibration.handler)
    register_handler!(:run_scenario, RunWorkflow.scenario_handler)
    register_handler!(:run_experiment, RunWorkflow.experiment_handler)
    register_handler!(:run_reporter, RunReporter.handler)
    register_handler!(:provenance, Provenance.handler)
    register_handler!(:model_status, ModelStatus.handler)
    register_handler!(:solve, Solve.handler)
    register_handler!(:render_equations, RenderEquations.handler)
    register_handler!(:render_model, RenderModel.handler)
    register_handler!(:validate_model, ValidateModel.handler)
    register_handler!(:export_results, ExportResults.handler)
    return nothing
end

end # module
