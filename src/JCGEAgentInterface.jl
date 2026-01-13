"""
MCP-compatible interface layer for JCGE tooling.
"""
module JCGEAgentInterface

include("Schema.jl")
include("Handlers.jl")
include("Context.jl")
include("Server.jl")
include("Actions/list_packages.jl")
include("Actions/load_model.jl")
include("Actions/solve.jl")
include("Actions/render_equations.jl")
include("Actions/export_results.jl")

using .Schema: ActionRequest, ActionResponse, request, response
using .Handlers: register_handler!, handle_request, default_handlers
using .Server: serve
using .Context: AgentContext, register_model!, model_names
using .ListPackages
using .LoadModel
using .Solve
using .RenderEquations
using .ExportResults

export ActionRequest, ActionResponse, request, response
export AgentContext, register_model!, model_names
export register_handler!, handle_request, default_handlers
export serve

"""
Register the default action handlers.
"""
function __init__()
    register_handler!(:list_packages, ListPackages.handler)
    register_handler!(:load_model, LoadModel.handler)
    register_handler!(:solve, Solve.handler)
    register_handler!(:render_equations, RenderEquations.handler)
    register_handler!(:export_results, ExportResults.handler)
    return nothing
end

end # module
