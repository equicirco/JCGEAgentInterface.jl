"""
Schema types for MCP-style requests and responses.
"""
module Schema

export ActionRequest, ActionResponse, request, response, request_from_dict
export validate_request, validate_response

"""
    ActionRequest(id, action, payload)

Structured request used by the agent interface.
"""
struct ActionRequest
    id::String
    action::Symbol
    payload::Dict{Symbol,Any}
end

"""
    ActionResponse(id; ok=true, data=Dict(), error=nothing)

Structured response for agent requests.
"""
struct ActionResponse
    id::String
    ok::Bool
    data::Dict{Symbol,Any}
    error::Union{Nothing,String}
end

"""
    request_from_dict(data)

Construct an ActionRequest from a Dict parsed from JSON.
"""
function request_from_dict(data::AbstractDict)
    id = string(get(data, :id, ""))
    action = Symbol(get(data, :action, ""))
    payload = Dict{Symbol,Any}()
    raw_payload = get(data, :payload, Dict{Any,Any}())
    if raw_payload isa AbstractDict
        for (k, v) in raw_payload
            payload[Symbol(k)] = _payload_value(v)
        end
    end
    return ActionRequest(id, action, payload)
end

function _payload_value(value)
    if value isa AbstractDict
        out = Dict{Symbol,Any}()
        for (k, v) in value
            out[Symbol(k)] = _payload_value(v)
        end
        return out
    elseif value isa AbstractVector
        return Any[_payload_value(v) for v in value]
    else
        return value
    end
end

const REQUIRED_FIELDS = Dict{Symbol,Vector{Symbol}}(
    :load_model => [:name],
    :describe_block => [:name],
)

"""
    validate_request(req)

Return `(ok, message)` after validating an ActionRequest.
"""
function validate_request(req::ActionRequest)
    isempty(req.id) && return (false, "request.id must be non-empty")
    req.action === Symbol("") && return (false, "request.action must be set")
    req.payload isa Dict{Symbol,Any} || return (false, "request.payload must be Dict{Symbol,Any}")
    required = get(REQUIRED_FIELDS, req.action, Symbol[])
    for key in required
        if !haskey(req.payload, key)
            return (false, "request.payload missing required key $(key)")
        end
    end
    return (true, "")
end

"""
    validate_response(resp)

Return `(ok, message)` after validating an ActionResponse.
"""
function validate_response(resp::ActionResponse)
    isempty(resp.id) && return (false, "response.id must be non-empty")
    resp.data isa Dict{Symbol,Any} || return (false, "response.data must be Dict{Symbol,Any}")
    resp.ok || resp.error !== nothing || return (false, "response.error must be set when ok=false")
    return (true, "")
end

"""
    request(id, action; payload=Dict())

Convenience constructor for ActionRequest.
"""
function request(id::AbstractString, action::Symbol; payload::AbstractDict=Dict{Symbol,Any}())
    parsed_payload = _payload_value(payload)
    parsed_payload isa Dict{Symbol,Any} || error("payload must convert to Dict{Symbol,Any}")
    return ActionRequest(String(id), action, parsed_payload)
end

"""
    response(id; ok=true, data=Dict(), error=nothing)

Convenience constructor for ActionResponse.
"""
function response(id::AbstractString; ok::Bool=true, data::AbstractDict=Dict{Symbol,Any}(), error::Union{Nothing,String}=nothing)
    parsed_data = _payload_value(data)
    parsed_data isa Dict{Symbol,Any} || error("data must convert to Dict{Symbol,Any}")
    return ActionResponse(String(id), ok, parsed_data, error)
end

end # module
