"""
Return guidance on currently available JCGE calibration utilities.
"""
module CalibrationGuide

using ..Schema: ActionRequest, response
using ..Catalog: calibration_guide

export handler

function handler(req::ActionRequest; ctx=nothing)
    return response(req.id; data=calibration_guide())
end

end # module
