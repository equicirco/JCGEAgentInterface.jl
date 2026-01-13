"""
Request routing and handler registration.
"""
module Handlers

using ..Schema: ActionRequest, ActionResponse, response

export register_handler!, handle_request, default_handlers

const HANDLERS = Dict{Symbol,Function}()

"""
    register_handler!(action, handler)

Register a handler function for an action symbol.
"""
function register_handler!(action::Symbol, handler::Function)
    HANDLERS[action] = handler
    return HANDLERS
end

"""
    handle_request(req; ctx=nothing)

Dispatch a request to a registered handler.
"""
function handle_request(req::ActionRequest; ctx=nothing)
    handler = get(HANDLERS, req.action, nothing)
    if handler === nothing
        return response(req.id; ok=false, error="Unknown action $(req.action)")
    end
    return handler(req; ctx=ctx)
end

"""
    default_handlers()

Return a shallow copy of the current handler map.
"""
function default_handlers()
    return Dict(HANDLERS)
end

end # module
