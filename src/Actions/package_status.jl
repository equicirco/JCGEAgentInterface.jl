"""
Report JCGE package status in the active Julia environment.
"""
module PackageStatus

using ..Schema: ActionRequest, response
using ..Catalog: package_inventory

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=Dict(:packages => package_inventory()))
end

end # module
