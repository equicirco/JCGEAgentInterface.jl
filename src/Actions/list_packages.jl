"""
List registered models and JCGE package versions.
"""
module ListPackages

using ..Schema: ActionRequest, response
using ..Context: model_names
using ..Catalog: package_inventory

export handler

"""
    handler(req; ctx=nothing)

Return registered model names and JCGE package versions.
"""
function handler(req::ActionRequest; ctx=nothing)
    models = String[]
    if ctx !== nothing
        try
            models = model_names(ctx)
        catch
            models = String[]
        end
    end
    return response(req.id; data=Dict(:models => models, :packages => package_inventory()))
end

end # module
