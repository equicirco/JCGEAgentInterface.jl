"""
Return structured guidance for developing CGE models with JCGE.
"""
module ModelingGuide

using ..Schema: ActionRequest, response
using ..Catalog: modeling_guide

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=modeling_guide())
end

end # module
