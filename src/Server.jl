"""
Minimal MCP server stub.
"""
module Server

using JSON3
using HTTP
using ..Schema: ActionRequest, ActionResponse, request_from_dict, validate_request, validate_response
using ..Handlers: handle_request
using ..Context: AgentContext

export serve

function _parse_request(line::AbstractString)
    data = JSON3.read(line)
    dict = Dict{Symbol,Any}()
    for (k, v) in pairs(data)
        dict[Symbol(k)] = v
    end
    return request_from_dict(dict)
end

function _handle_request(req::ActionRequest, ctx)
    ok, msg = validate_request(req)
    resp = ok ? handle_request(req; ctx=ctx) : ActionResponse(req.id, false, Dict{Symbol,Any}(), msg)
    ok_resp, msg_resp = validate_response(resp)
    ok_resp || error("Invalid response: $(msg_resp)")
    return resp
end

"""
    serve(; transport=:stdio, ctx=nothing, host="127.0.0.1", port=8080)

Start the agent interface server.

Read JSON requests from stdin and write JSON responses to stdout, or serve
HTTP/WS requests when `transport=:http` or `:ws`.
"""
function serve(; transport::Symbol=:stdio, ctx=nothing, host::AbstractString="127.0.0.1", port::Integer=8080)
    ctx = ctx === nothing ? AgentContext() : ctx
    if transport == :stdio
        for line in eachline(stdin)
            stripped = strip(line)
            isempty(stripped) && continue
            req = _parse_request(stripped)
            resp = _handle_request(req, ctx)
            println(JSON3.write(resp))
        end
        return nothing
    elseif transport == :http
        handler = HTTP.serve!((req::HTTP.Request) -> begin
            req.method == "POST" || return HTTP.Response(405, "Method Not Allowed")
            areq = _parse_request(String(req.body))
            resp = _handle_request(areq, ctx)
            return HTTP.Response(200, JSON3.write(resp))
        end, host, port; verbose=false)
        return handler
    elseif transport == :ws
        return HTTP.WebSockets.listen(host, port) do ws
            for msg in ws
                req = _parse_request(String(msg))
                resp = _handle_request(req, ctx)
                HTTP.WebSockets.send(ws, JSON3.write(resp))
            end
        end
    else
        error("Unsupported transport: $(transport)")
    end
end

end # module
