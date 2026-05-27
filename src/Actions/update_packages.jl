"""
Update released JCGE packages in the active Julia environment.
"""
module UpdatePackages

using Pkg
using ..Schema: ActionRequest, response
using ..Catalog: JCGE_PACKAGE_NAMES, package_inventory

export handler

function _requested_packages(payload)
    raw = get(payload, :packages, nothing)
    raw === nothing && return JCGE_PACKAGE_NAMES
    raw isa AbstractVector || error("payload[:packages] must be an array of package names")
    names = String.(raw)
    unknown = setdiff(names, JCGE_PACKAGE_NAMES)
    isempty(unknown) || error("Unknown JCGE package names: $(join(unknown, ", "))")
    return names
end

function handler(req::ActionRequest; ctx=nothing)
    apply = get(req.payload, :apply, false) == true
    packages = try
        _requested_packages(req.payload)
    catch err
        return response(req.id; ok=false, error=string(err))
    end

    if !apply
        command = "using Pkg; Pkg.update([" * join(["Pkg.PackageSpec(name=\"$(name)\")" for name in packages], ", ") * "])"
        return response(req.id; data=Dict(
            :mode => "dry_run",
            :packages => packages,
            :message => "Set apply=true to update these released JCGE packages in the active Julia environment.",
            :command => command,
            :current => package_inventory(),
        ))
    end

    specs = [Pkg.PackageSpec(name=name) for name in packages]
    Pkg.update(specs)
    Pkg.resolve()
    return response(req.id; data=Dict(
        :mode => "applied",
        :packages => packages,
        :current => package_inventory(),
    ))
end

end # module
