# Examples

## List packages

```julia
using JCGEAgentInterface

ctx = AgentContext()
req = request("1", :list_packages)
resp = handle_request(req; ctx=ctx)
```

## Load a model

```julia
register_model!(ctx, "StandardCGE", JCGEExamples.StandardCGE.model)
req = request("2", :load_model; payload=Dict(:name => "StandardCGE"))
resp = handle_request(req; ctx=ctx)
```

## Solve (stub)

```julia
req = request("3", :solve; payload=Dict(:model => "StandardCGE"))
resp = handle_request(req; ctx=ctx)
```

## Stdio server

```julia
serve()
```
