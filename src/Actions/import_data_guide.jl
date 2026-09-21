"""
Return guidance on source-neutral JCGE import-data support.
"""
module ImportDataGuide

using ..Schema: ActionRequest, response
using ..Catalog: import_data_guide

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=import_data_guide())
end

end # module
