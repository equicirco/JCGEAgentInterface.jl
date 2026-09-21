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
    format in (:markdown, :latex, :plain) ||
        return response(req.id; ok=false, error="Unsupported render format $(format)")

    text = if kind == :equations
        level = Symbol(get(req.payload, :level, :block))
        view = Symbol(get(req.payload, :view, :expanded))
        show_defs = get(req.payload, :show_defs, true)
        show_condition_roles = get(req.payload, :show_condition_roles, false)
        latex_width = get(req.payload, :latex_width, 100)
        level in (:block, :equation) ||
            return response(req.id; ok=false, error="Unsupported equation level $(level)")
        view in (:expanded, :family) ||
            return response(req.id; ok=false, error="Unsupported equation view $(view)")
        show_defs isa Bool ||
            return response(req.id; ok=false, error="show_defs must be boolean")
        show_condition_roles isa Bool ||
            return response(req.id; ok=false, error="show_condition_roles must be boolean")
        latex_width isa Integer && latex_width >= 20 ||
            return response(req.id; ok=false, error="latex_width must be an integer of at least 20")
        JCGEOutput.render_equations(target; format=format, level=level, view=view,
            show_defs=show_defs, show_condition_roles=show_condition_roles,
            latex_width=latex_width)
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
