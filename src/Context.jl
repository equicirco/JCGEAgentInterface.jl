"""
Shared context for agent actions.
"""
module Context

export AgentContext, register_model!, model_names

"""
    AgentContext(; models=Dict())

Store models and last run artifacts for agent actions.
"""
mutable struct AgentContext
    models::Dict{String,Any}
    last_spec::Any
    last_result::Any
end

"""
    AgentContext(; models=Dict())

Create an AgentContext with an optional model registry.
"""
function AgentContext(; models::Dict{String,Any}=Dict{String,Any}())
    return AgentContext(models, nothing, nothing)
end

"""
    register_model!(ctx, name, model)

Register a model (RunSpec or zero-arg function returning a RunSpec).
"""
function register_model!(ctx::AgentContext, name::AbstractString, model)
    ctx.models[String(name)] = model
    return ctx
end

"""
    model_names(ctx)

Return available model names.
"""
function model_names(ctx::AgentContext)
    return sort(collect(keys(ctx.models)))
end

end # module
