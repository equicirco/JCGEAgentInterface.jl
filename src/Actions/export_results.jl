"""
Export results from a run.
"""
module ExportResults

using ..Schema: ActionRequest, response
using ..Context: AgentContext
using JCGEOutput

export handler

"""
    handler(req; ctx=nothing)

Export results from the last solve as a tidy table.
"""
function handler(req::ActionRequest; ctx=nothing)
    if !(ctx isa AgentContext) || ctx.last_result === nothing
        return response(req.id; ok=false, error="No results available. Solve a model first.")
    end
    results = JCGEOutput.collect_results(ctx.last_result)
    table = JCGEOutput.tidy(results)
    return response(req.id; data=Dict(:table => table))
end

end # module
