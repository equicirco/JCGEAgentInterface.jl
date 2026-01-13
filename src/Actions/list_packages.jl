"""
List packages available in the JCGE ecosystem.
"""
module ListPackages

using ..Schema: ActionRequest, response
using ..Context: model_names

export handler

"""
    handler(req; ctx=nothing)

Return a list of known packages. Provide `ctx.packages` to override.
"""
function handler(req::ActionRequest; ctx=nothing)
    packages = String[]
    if ctx !== nothing
        try
            packages = model_names(ctx)
        catch
            packages = String[]
        end
    end
    return response(req.id; data=Dict(:packages => packages))
end

end # module
