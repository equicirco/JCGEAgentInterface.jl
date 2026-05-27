"""
List available JCGE blocks and helper constructors.
"""
module ListBlocks

using ..Schema: ActionRequest, response
using ..Catalog: block_catalog

export handler

function handler(req::ActionRequest; ctx=nothing)
    group = get(req.payload, :group, nothing)
    return response(req.id; data=block_catalog(group=group))
end

end # module
