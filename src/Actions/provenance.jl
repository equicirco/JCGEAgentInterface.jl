"""
Return session-scoped model-study provenance records.
"""
module Provenance

using ..Schema: ActionRequest, response
using ..Context: AgentContext, provenance_records

export handler

"""
    handler(req; ctx=nothing)

Return all provenance records for the current server session, or one record
when `payload[:record_id]` is supplied. The caller can persist this structured
response; the server does not write user data to disk.
"""
function handler(req::ActionRequest; ctx=nothing)
    ctx isa AgentContext || return response(req.id; ok=false, error="No agent context is available.")
    record_id = get(req.payload, :record_id, nothing)
    record_id === nothing || record_id isa AbstractString ||
        return response(req.id; ok=false, error="payload[:record_id] must be a string.")
    records = provenance_records(ctx; record_id=record_id)
    if record_id !== nothing && records === nothing
        return response(req.id; ok=false, error="Unknown provenance record $(record_id).")
    end
    return response(req.id; data=record_id === nothing ?
        Dict(:records => records) : Dict(:record => records))
end

end # module
