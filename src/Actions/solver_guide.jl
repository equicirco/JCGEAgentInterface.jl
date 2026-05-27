"""
Return guidance on solver choice and diagnostics.
"""
module SolverGuide

using ..Schema: ActionRequest, response
using ..Catalog: solver_guide

export handler

function handler(req::ActionRequest; ctx=nothing)
    formulation = get(req.payload, :formulation, nothing)
    return response(req.id; data=solver_guide(formulation=formulation))
end

end # module
