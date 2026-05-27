"""
Render equations for a model.
"""
module RenderEquations

using ..Schema: ActionRequest
using ..RenderModel

export handler

"""
    handler(req; ctx=nothing)

Render equations for the last solved model or a named model.
"""
function handler(req::ActionRequest; ctx=nothing)
    payload = copy(req.payload)
    payload[:kind] = :equations
    return RenderModel.handler(ActionRequest(req.id, :render_model, payload); ctx=ctx)
end

end # module
