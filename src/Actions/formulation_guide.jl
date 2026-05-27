"""
Return guidance on JCGE mathematical formulations.
"""
module FormulationGuide

using ..Schema: ActionRequest, response
using ..Catalog: formulation_guide

export handler

function handler(req::ActionRequest; ctx=nothing)
    topic = get(req.payload, :topic, nothing)
    return response(req.id; data=formulation_guide(topic=topic))
end

end # module
