"""
Describe one JCGE block helper or block type.
"""
module DescribeBlock

using ..Schema: ActionRequest, response
using ..Catalog: describe_block

export handler

function handler(req::ActionRequest; ctx=nothing)
    name = get(req.payload, :name, nothing)
    name === nothing && return response(req.id; ok=false, error="Missing payload[:name]")
    entry = describe_block(String(name))
    entry === nothing && return response(req.id; ok=false, error="Unknown block or helper $(name)")
    return response(req.id; data=Dict(:block => entry))
end

end # module
