"""
Report JCGE agent capabilities.
"""
module Capabilities

using ..Schema: ActionRequest, response
using ..Catalog: capability_catalog

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=capability_catalog())
end

end # module
