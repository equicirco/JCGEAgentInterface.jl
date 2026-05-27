# Usage

`JCGEAgentInterface` defines a small action API and a standard MCP stdio server.

## Requests

```julia
using JCGEAgentInterface

req = request("1", :capabilities)
resp = handle_request(req)
```

Useful discovery actions include:

- `:capabilities`
- `:list_blocks`
- `:describe_block`
- `:modeling_guide`
- `:formulation_guide`
- `:solver_guide`
- `:calibration_guide`
- `:reporting_guide`
- `:package_status`
- `:update_packages`

## Extending

Register custom handlers with `register_handler!` and integrate a transport
layer that maps JSON to `ActionRequest`.

## MCP stdio transport

```julia
serve(transport=:mcp_stdio)
```

This transport implements JSON-RPC MCP methods:

- `initialize`
- `tools/list`
- `tools/call`
- `ping`

## Legacy stdio transport

The built-in `serve()` function reads JSON lines from stdin and writes JSON
responses to stdout.

## HTTP transport

```julia
serve(transport=:http, host="127.0.0.1", port=8080)
```

Send a JSON request via POST to `/` and receive a JSON response.

## WebSocket transport

```julia
serve(transport=:ws, host="127.0.0.1", port=8081)
```

Send JSON messages over the socket and receive JSON replies.
