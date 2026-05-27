"""
Transport layer for the JCGE agent interface.
"""
module Server

using JSON3
using HTTP
using ..Schema: ActionRequest, ActionResponse, request_from_dict, validate_request, validate_response
using ..Handlers: handle_request
using ..Context: AgentContext
using ..Catalog: MCP_TOOL_ACTIONS, mcp_tool_definitions

export serve, MCPServer, handle_mcp_message

const SUPPORTED_PROTOCOL_VERSIONS = (
    "2024-11-05",
    "2025-03-26",
    "2025-06-18",
    "2025-11-25",
)
const LATEST_PROTOCOL_VERSION = SUPPORTED_PROTOCOL_VERSIONS[end]

const JSONRPC_INVALID_REQUEST = -32600
const JSONRPC_METHOD_NOT_FOUND = -32601
const JSONRPC_INVALID_PARAMS = -32602

mutable struct MCPServer
    ctx::AgentContext
    initialized::Bool
    protocol_version::String
end

MCPServer(; ctx=nothing) = MCPServer(ctx === nothing ? AgentContext() : ctx, false, LATEST_PROTOCOL_VERSION)

function _plain(value)
    if value isa JSON3.Object
        out = Dict{String,Any}()
        for (k, v) in pairs(value)
            out[string(k)] = _plain(v)
        end
        return out
    elseif value isa JSON3.Array
        return Any[_plain(v) for v in value]
    else
        return value
    end
end

function _symbol_dict(data::AbstractDict)
    out = Dict{Symbol,Any}()
    for (k, v) in data
        out[Symbol(k)] = _symbol_value(v)
    end
    return out
end

function _symbol_value(value)
    if value isa AbstractDict
        return _symbol_dict(value)
    elseif value isa AbstractVector
        return Any[_symbol_value(v) for v in value]
    else
        return value
    end
end

function _json_ready(value)
    if value isa AbstractDict
        out = Dict{String,Any}()
        for (k, v) in value
            out[string(k)] = _json_ready(v)
        end
        return out
    elseif value isa NamedTuple
        return Dict{String,Any}(string(k) => _json_ready(v) for (k, v) in pairs(value))
    elseif value isa Tuple
        return Any[_json_ready(v) for v in value]
    elseif value isa AbstractVector
        return Any[_json_ready(v) for v in value]
    elseif value isa Symbol || value isa VersionNumber
        return string(value)
    elseif value === nothing || value isa AbstractString || value isa Number || value isa Bool
        return value
    else
        return string(value)
    end
end

function _parse_request(line::AbstractString)
    data = _plain(JSON3.read(line))
    data isa AbstractDict || error("Request must be a JSON object")
    return request_from_dict(_symbol_dict(data))
end

function _handle_request(req::ActionRequest, ctx)
    ok, msg = validate_request(req)
    resp = ok ? handle_request(req; ctx=ctx) : ActionResponse(req.id, false, Dict{Symbol,Any}(), msg)
    ok_resp, msg_resp = validate_response(resp)
    ok_resp || error("Invalid response: $(msg_resp)")
    return resp
end

_mcp_response(id, result) = Dict("jsonrpc" => "2.0", "id" => id, "result" => result)
_mcp_error(id, code, message) = Dict("jsonrpc" => "2.0", "id" => id, "error" => Dict("code" => code, "message" => message))

function _server_version()
    version = try
        Base.pkgversion(parentmodule(@__MODULE__))
    catch
        nothing
    end
    return version === nothing ? "unknown" : string(version)
end

function _tool_result(data; is_error::Bool=false)
    body = _json_ready(data)
    return Dict(
        "content" => [Dict("type" => "text", "text" => JSON3.write(body))],
        "structuredContent" => body,
        "isError" => is_error,
    )
end

function _require_initialized(server::MCPServer, request_id)
    server.initialized && return nothing
    return _mcp_error(request_id, JSONRPC_INVALID_REQUEST, "The client must send initialize before calling MCP tools.")
end

function _handle_initialize(server::MCPServer, request_id, params::AbstractDict)
    request_id === nothing && return _mcp_error(nothing, JSONRPC_INVALID_REQUEST, "initialize must be a request.")
    requested = get(params, "protocolVersion", nothing)
    if requested isa AbstractString && requested in SUPPORTED_PROTOCOL_VERSIONS
        server.protocol_version = String(requested)
    else
        server.protocol_version = LATEST_PROTOCOL_VERSION
    end
    server.initialized = true
    return _mcp_response(request_id, Dict(
        "protocolVersion" => server.protocol_version,
        "capabilities" => Dict("tools" => Dict("listChanged" => false)),
        "serverInfo" => Dict(
            "name" => "jcge-agentinterface-mcp",
            "title" => "JCGE Agent Interface MCP Server",
            "version" => _server_version(),
        ),
        "instructions" => "Use the JCGE tools to discover blocks and package capabilities, guide CGE model development, solve registered models, validate results, and render implemented equations.",
    ))
end

function _handle_tools_list(server::MCPServer, request_id)
    err = _require_initialized(server, request_id)
    err === nothing || return err
    return _mcp_response(request_id, Dict("tools" => mcp_tool_definitions()))
end

function _handle_tools_call(server::MCPServer, request_id, params::AbstractDict)
    err = _require_initialized(server, request_id)
    err === nothing || return err
    name = get(params, "name", nothing)
    arguments = get(params, "arguments", Dict{String,Any}())
    name isa AbstractString || return _mcp_error(request_id, JSONRPC_INVALID_PARAMS, "Tool name must be a string.")
    arguments isa AbstractDict || return _mcp_error(request_id, JSONRPC_INVALID_PARAMS, "Tool arguments must be an object.")
    action = get(MCP_TOOL_ACTIONS, String(name), nothing)
    action === nothing && return _mcp_error(request_id, JSONRPC_METHOD_NOT_FOUND, "Unknown tool: $(name)")

    req = ActionRequest(string(request_id), action, _symbol_dict(arguments))
    ok, msg = validate_request(req)
    ok || return _mcp_error(request_id, JSONRPC_INVALID_PARAMS, msg)

    try
        resp = _handle_request(req, server.ctx)
        if resp.ok
            return _mcp_response(request_id, _tool_result(resp.data; is_error=false))
        else
            return _mcp_response(request_id, _tool_result(Dict(:error => resp.error); is_error=true))
        end
    catch err
        return _mcp_response(request_id, _tool_result(Dict(:error => string(err)); is_error=true))
    end
end

"""
    handle_mcp_message(server, payload)

Process one MCP JSON-RPC message or batch. Returns response objects; notifications
return an empty vector.
"""
function handle_mcp_message(server::MCPServer, payload)
    if payload isa AbstractVector
        responses = Any[]
        for item in payload
            append!(responses, handle_mcp_message(server, item))
        end
        return responses
    end
    payload isa AbstractDict || return [_mcp_error(nothing, JSONRPC_INVALID_REQUEST, "Request must be a JSON object.")]
    haskey(payload, "method") || return Any[]

    method = payload["method"]
    request_id = get(payload, "id", nothing)
    params = get(payload, "params", Dict{String,Any}())
    params === nothing && (params = Dict{String,Any}())
    params isa AbstractDict || return [_mcp_error(request_id, JSONRPC_INVALID_PARAMS, "Request params must be an object.")]

    if method == "initialize"
        return [_handle_initialize(server, request_id, params)]
    elseif method == "notifications/initialized"
        return Any[]
    elseif method == "ping"
        return [_mcp_response(request_id, Dict{String,Any}())]
    elseif method == "tools/list"
        return [_handle_tools_list(server, request_id)]
    elseif method == "tools/call"
        return [_handle_tools_call(server, request_id, params)]
    else
        return [_mcp_error(request_id, JSONRPC_METHOD_NOT_FOUND, "Unsupported method: $(method)")]
    end
end

"""
    serve(; transport=:stdio, ctx=nothing, host="127.0.0.1", port=8080)

Start the agent interface server.

Use `transport=:mcp_stdio` for standard MCP JSON-RPC over newline-delimited
stdio. The original `transport=:stdio` custom action protocol is kept for
backward compatibility. HTTP/WS transports use the custom action protocol.
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
    elseif transport == :mcp_stdio
        server = MCPServer(ctx=ctx)
        for line in eachline(stdin)
            stripped = strip(line)
            isempty(stripped) && continue
            payload = _plain(JSON3.read(stripped))
            responses = handle_mcp_message(server, payload)
            isempty(responses) && continue
            out = payload isa AbstractVector ? responses : first(responses)
            println(JSON3.write(out))
            flush(stdout)
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
