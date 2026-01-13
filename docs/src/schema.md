# Schema

Requests and responses are structured as Julia types. A transport layer should
map JSON to these types and back.

## Request

- `id::String`
- `action::Symbol`
- `payload::Dict{Symbol,Any}`

`validate_request` enforces non-empty `id`, a defined `action`, and required
payload keys (for example `:name` for `:load_model`).

## Response

- `id::String`
- `ok::Bool`
- `data::Dict{Symbol,Any}`
- `error::Union{Nothing,String}`

`validate_response` requires `error` to be set when `ok=false`.

## Example

```julia
using JCGEAgentInterface

req = request("1", :list_packages)
resp = handle_request(req)
```
