# Usage

`JCGEAgentInterface` defines an MCP-style request/response surface.

## Requests

```julia
using JCGEAgentInterface

req = request("1", :list_packages)
resp = handle_request(req)
```

## Extending

Register custom handlers with `register_handler!` and integrate a transport
layer that maps JSON to `ActionRequest`.

## Stdio transport

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
