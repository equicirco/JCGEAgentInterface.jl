"""
List registered models and JCGE package versions.
"""
module ListPackages

using ..Schema: ActionRequest, response
using ..Context: AgentContext, model_names, model_adapter, active_model_adapter
using ..Adapters: adapter_summary, compatibility_status
using ..Catalog: package_inventory, package_version_map

export handler

"""
    handler(req; ctx=nothing)

Return registered model names, declared adapter capabilities, and JCGE package
versions. The names-only `models` field is retained for existing clients;
`model_adapters` contains the machine-readable contract summaries.
"""
function handler(req::ActionRequest; ctx=nothing)
    models = String[]
    packages = package_inventory()
    if !(ctx isa AgentContext)
        return response(req.id; data=Dict(
            :models => models,
            :model_adapters => Any[],
            :active_model => nothing,
            :packages => packages,
        ))
    end

    models = model_names(ctx)
    versions = package_version_map()
    adapters = Any[]
    for name in models
        adapter = model_adapter(ctx, name)
        adapter === nothing && continue
        summary = adapter_summary(adapter)
        summary[:compatibility_status] = compatibility_status(adapter, versions)
        push!(adapters, summary)
    end
    active = active_model_adapter(ctx)
    return response(req.id; data=Dict(
        :models => models,
        :model_adapters => adapters,
        :active_model => active === nothing ? nothing : active.name,
        :packages => packages,
    ))
end

end # module
