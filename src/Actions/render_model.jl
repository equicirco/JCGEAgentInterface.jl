"""
Render model equations, blocks, or symbols through JCGEOutput.
"""
module RenderModel

using ..Schema: ActionRequest, response
using ..Context: AgentContext
using JCGEOutput

export handler

function _target(ctx)
    ctx isa AgentContext || return nothing
    return ctx.last_result !== nothing ? ctx.last_result : ctx.last_spec
end

function handler(req::ActionRequest; ctx=nothing)
    target = _target(ctx)
    target === nothing && return response(req.id; ok=false, error="No model in context. Solve or load a model first.")

    kind = Symbol(get(req.payload, :kind, :equations))
    format = Symbol(get(req.payload, :format, :markdown))

    text = if kind == :equations
        JCGEOutput.render_equations(target; format=format)
    elseif kind == :blocks
        JCGEOutput.render_blocks(target; format=format)
    elseif kind == :symbols
        JCGEOutput.render_symbols(target; format=format)
    else
        return response(req.id; ok=false, error="Unsupported render kind $(kind)")
    end

    return response(req.id; data=Dict(:kind => String(kind), :format => String(format), :text => text))
end

end # module
