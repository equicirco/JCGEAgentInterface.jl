"""
Shared context for agent actions.
"""
module Context

using ..Adapters: ModelAdapter, transport_value

export AgentContext, register_model!, model_names, model_adapter, active_model_adapter
export record_provenance!, provenance_records

"""
    AgentContext(; models=Dict())

Store models and last run artifacts for agent actions.
"""
mutable struct AgentContext
    models::Dict{String,ModelAdapter}
    active_model::Union{Nothing,String}
    calibration_model::Union{Nothing,String}
    calibration_available::Bool
    last_calibration::Any
    workflow_model::Union{Nothing,String}
    workflow_kind::Union{Nothing,Symbol}
    workflow_name::Union{Nothing,String}
    last_workflow::Any
    result_model::Union{Nothing,String}
    last_spec::Any
    last_result::Any
    report_model::Union{Nothing,String}
    report_name::Union{Nothing,String}
    last_report::Any
    next_record_id::Int
    provenance::Vector{Dict{String,Any}}
end

"""
    AgentContext(; models=Dict())

Create an `AgentContext` with an optional model registry. Values may be
`ModelAdapter` instances or legacy `RunSpec`/zero-argument model values. Legacy
values are wrapped in a minimal `ModelAdapter`.
"""
function AgentContext(; models::AbstractDict=Dict{String,Any}())
    ctx = AgentContext(
        Dict{String,ModelAdapter}(), nothing, nothing, false, nothing,
        nothing, nothing, nothing, nothing, nothing, nothing,
        nothing, nothing, nothing, nothing,
        1, Dict{String,Any}[],
    )
    for (name, model) in models
        adapter = model isa ModelAdapter ? model : ModelAdapter(string(name), model)
        adapter.name == string(name) ||
            throw(ArgumentError("Model registry key $(name) does not match adapter name $(adapter.name)."))
        register_model!(ctx, adapter)
    end
    return ctx
end

"""
    register_model!(ctx, adapter; replace=false)

Register a typed model adapter. A duplicate name is rejected unless
`replace=true` is explicitly supplied.
"""
function register_model!(ctx::AgentContext, adapter::ModelAdapter; replace::Bool=false)
    haskey(ctx.models, adapter.name) && !replace &&
        throw(ArgumentError("Model $(adapter.name) is already registered. Pass replace=true to replace it."))
    ctx.models[adapter.name] = adapter
    return ctx
end

"""
    register_model!(ctx, name, model; kwargs...)

Compatibility registration path for a `RunSpec` or zero-argument model
constructor. Keyword arguments are forwarded to `ModelAdapter`, enabling a
model package to adopt the adapter contract without changing the registry API.
"""
function register_model!(ctx::AgentContext, name::AbstractString, model;
                         replace::Bool=false, kwargs...)
    return register_model!(ctx, ModelAdapter(name, model; kwargs...); replace=replace)
end

"""
    model_names(ctx)

Return available model names.
"""
function model_names(ctx::AgentContext)
    return sort(collect(keys(ctx.models)))
end

"""
    model_adapter(ctx, name)

Return the registered typed adapter for `name`, or `nothing` when the model is
not registered.
"""
model_adapter(ctx::AgentContext, name::AbstractString) = get(ctx.models, String(name), nothing)

"""
    active_model_adapter(ctx)

Return the currently selected model adapter, or `nothing` when no model has
been loaded.
"""
function active_model_adapter(ctx::AgentContext)
    ctx.active_model === nothing && return nothing
    return model_adapter(ctx, ctx.active_model)
end

"""
    record_provenance!(ctx; event, model=nothing, details=Dict())

Append one immutable-in-practice, transport-safe provenance record to this
server session. The record ID is ordered within the session; persistence is
intentionally left to the MCP client through the provenance action.
"""
function record_provenance!(ctx::AgentContext;
                            event::Symbol,
                            model::Union{Nothing,AbstractString}=nothing,
                            details::AbstractDict=Dict{String,Any}())
    adapter = model === nothing ? nothing : model_adapter(ctx, String(model))
    record = Dict{String,Any}(
        "record_id" => "record-" * lpad(string(ctx.next_record_id), 6, '0'),
        "recorded_at_unix" => time(),
        "event" => String(event),
        "model" => model === nothing ? nothing : String(model),
        "model_version" => adapter === nothing ? nothing : adapter.version,
        "compatibility" => adapter === nothing ? Dict{String,String}() : copy(adapter.compatibility),
        "details" => transport_value(details; field="Provenance details"),
    )
    push!(ctx.provenance, record)
    ctx.next_record_id += 1
    return deepcopy(record)
end

"""
    provenance_records(ctx; record_id=nothing)

Return copies of all session provenance records, or the single matching record.
"""
function provenance_records(ctx::AgentContext; record_id::Union{Nothing,AbstractString}=nothing)
    if record_id === nothing
        return deepcopy(ctx.provenance)
    end
    match = findfirst(record -> record["record_id"] == String(record_id), ctx.provenance)
    return match === nothing ? nothing : deepcopy(ctx.provenance[match])
end

end # module
