"""
Return guidance on generated JCGE reporting outputs.
"""
module ReportingGuide

using ..Schema: ActionRequest, response
using ..Catalog: reporting_guide

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=reporting_guide())
end

end # module
