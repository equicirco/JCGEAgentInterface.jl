"""
List reference CGE example modules available in JCGEExamples.
"""
module ListExamples

using ..Schema: ActionRequest, response
using ..Catalog: example_catalog

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=example_catalog())
end

end # module
