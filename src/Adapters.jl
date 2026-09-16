"""
Typed contracts for JCGE models exposed through an agent or MCP server.

Model packages remain the owners of their equations, data, calibration logic,
and scenario definitions.  This module only describes the explicit entry points
that a model package may register with `JCGEAgentInterface`.
"""
module Adapters

using Pkg

export CalibrationInput, WorkflowAdapter, ResultIndicator, ModelAdapter
export adapter_summary, build_model, calibration_input_status, calibration_diagnostics, compatibility_status
export WorkflowState, workflow_parameter_status, run_workflow, run_reporter, transport_value

"""
    CalibrationInput(name; description="", required=true, schema=Dict())

Describe one declared input to a model-owned calibration workflow. `schema` is
JSON-schema-like metadata for a future transport layer; it is descriptive and
does not itself load data or infer calibration assumptions.
"""
struct CalibrationInput
    name::String
    description::String
    required::Bool
    schema::Dict{String,Any}
end

function CalibrationInput(name::AbstractString;
                          description::AbstractString="",
                          required::Bool=true,
                          schema::AbstractDict=Dict{String,Any}())
    isempty(strip(name)) && throw(ArgumentError("Calibration input name must be non-empty."))
    return CalibrationInput(
        String(name),
        String(description),
        required,
        _transport_dict(schema, "Calibration input schema"),
    )
end

"""
    WorkflowAdapter(name; description="", parameters=Dict(), run)

Describe a declared scenario or experiment. `parameters` describes accepted
structured inputs; each parameter may declare `required=true` and a JSON-schema
primitive `type`. The model-owned callback receives `(state, parameters)`, so
an agent is limited to named workflows deliberately registered by the model
package rather than arbitrary code or equation edits.
"""
struct WorkflowAdapter
    name::String
    description::String
    parameters::Dict{String,Any}
    run::Function
end

"""
    WorkflowState

Read-only context supplied to a declared scenario or experiment callback. Model
packages can use the calibration artifact, built specification, and latest
result deliberately retained by the agent context; MCP clients cannot supply
or alter this state directly.
"""
struct WorkflowState
    model_name::String
    calibration_available::Bool
    calibration::Any
    spec::Any
    result::Any
end

function WorkflowAdapter(name::AbstractString, run::Function;
                         description::AbstractString="",
                         parameters::AbstractDict=Dict{String,Any}())
    isempty(strip(name)) && throw(ArgumentError("Workflow name must be non-empty."))
    return WorkflowAdapter(
        String(name),
        String(description),
        _transport_dict(parameters, "Workflow parameters"),
        run,
    )
end

"""
    ResultIndicator(name; description="", unit=nothing)

Describe a model-owned result indicator that may be returned by reporting or
comparison tools. It declares semantics only; extraction remains with the model
or its reporting callback.
"""
struct ResultIndicator
    name::String
    description::String
    unit::Union{Nothing,String}
end

function ResultIndicator(name::AbstractString;
                         description::AbstractString="",
                         unit::Union{Nothing,AbstractString}=nothing)
    isempty(strip(name)) && throw(ArgumentError("Result indicator name must be non-empty."))
    return ResultIndicator(String(name), String(description), unit === nothing ? nothing : String(unit))
end

"""
    ModelAdapter(name, build; kwargs...)

The explicit contract between a JCGE model package and the agent interface.

`build` returns a `JCGECore.RunSpec`. It may accept no arguments, or it may
accept the artifact returned by `calibrate(inputs)`. Passing a pre-built model
remains supported for compatibility and is wrapped in a zero-argument callback.

Optional callbacks remain model-owned:

- `calibrate(inputs)` performs an explicitly declared calibration workflow.
- `check_calibration(artifact)` returns model-specific calibration diagnostics.
- a `WorkflowAdapter.run` callback runs one named scenario or experiment.
- `reporters[name](result)` derives a named model-specific reporting artifact.

The MCP calls only these explicitly registered, model-owned entry points; it
does not execute arbitrary Julia supplied by an MCP client.
"""
struct ModelAdapter
    name::String
    description::String
    version::Union{Nothing,String}
    compatibility::Dict{String,String}
    build::Function
    calibration_inputs::Vector{CalibrationInput}
    calibrate::Union{Nothing,Function}
    check_calibration::Union{Nothing,Function}
    scenarios::Dict{String,WorkflowAdapter}
    experiments::Dict{String,WorkflowAdapter}
    indicators::Vector{ResultIndicator}
    reporters::Dict{String,Function}
    metadata::Dict{String,Any}
end

_as_build_callback(model::Function) = model
_as_build_callback(model) = () -> model

function _transport_value(value, field::AbstractString)
    if value === nothing || value isa Bool || value isa Number || value isa AbstractString
        return value
    elseif value isa AbstractVector || value isa Tuple
        return Any[_transport_value(item, field) for item in value]
    elseif value isa NamedTuple
        return Dict{String,Any}(
            string(key) => _transport_value(item, field) for (key, item) in pairs(value)
        )
    elseif value isa AbstractDict
        return _transport_dict(value, field)
    end
    throw(ArgumentError("$(field) must contain only JSON-compatible values, not $(typeof(value))."))
end

function _transport_dict(values::AbstractDict, field::AbstractString)
    return Dict{String,Any}(
        string(key) => _transport_value(value, field) for (key, value) in values
    )
end

"""
    transport_value(value; field="Value")

Convert structured model metadata or output to a transport-safe value. This is
also used for provenance snapshots; it rejects arbitrary objects rather than
silently serializing executable or opaque values.
"""
transport_value(value; field::AbstractString="Value") = _transport_value(value, field)

function _compatibility_index(compatibility::AbstractDict)
    indexed = Dict{String,String}()
    for (package, requirement) in compatibility
        package_name = strip(string(package))
        constraint = strip(string(requirement))
        isempty(package_name) && throw(ArgumentError("Compatibility package name must be non-empty."))
        isempty(constraint) && throw(ArgumentError("Compatibility requirement for $(package_name) must be non-empty."))
        try
            Pkg.Types.VersionSpec(constraint)
        catch error
            throw(ArgumentError("Invalid compatibility requirement $(constraint) for $(package_name): $(sprint(showerror, error))"))
        end
        haskey(indexed, package_name) &&
            throw(ArgumentError("Duplicate compatibility entry for $(package_name)."))
        indexed[package_name] = constraint
    end
    return indexed
end

function _workflow_index(workflows, kind::AbstractString)
    indexed = Dict{String,WorkflowAdapter}()
    for workflow in workflows
        workflow isa WorkflowAdapter || throw(ArgumentError("Each $(kind) must be a WorkflowAdapter."))
        haskey(indexed, workflow.name) && throw(ArgumentError("Duplicate $(kind) name $(workflow.name)."))
        indexed[workflow.name] = workflow
    end
    return indexed
end

function _validate_unique_names(items, kind::AbstractString)
    names = String[]
    for item in items
        push!(names, item.name)
    end
    length(unique(names)) == length(names) || throw(ArgumentError("Duplicate $(kind) names are not allowed."))
    return nothing
end

function _reporter_index(reporters::AbstractDict)
    indexed = Dict{String,Function}()
    for (name, reporter) in reporters
        reporter isa Function || throw(ArgumentError("Reporter $(name) must be a function."))
        key = string(name)
        isempty(strip(key)) && throw(ArgumentError("Reporter name must be non-empty."))
        indexed[key] = reporter
    end
    return indexed
end

function _registered_input_names(inputs::AbstractDict)
    return Set(string(key) for key in keys(inputs))
end

function ModelAdapter(name::AbstractString, model;
                      description::AbstractString="",
                      version::Union{Nothing,AbstractString}=nothing,
                      compatibility::AbstractDict=Dict{String,String}(),
                      calibration_inputs::AbstractVector=CalibrationInput[],
                      calibrate::Union{Nothing,Function}=nothing,
                      check_calibration::Union{Nothing,Function}=nothing,
                      scenarios::AbstractVector=WorkflowAdapter[],
                      experiments::AbstractVector=WorkflowAdapter[],
                      indicators::AbstractVector=ResultIndicator[],
                      reporters::AbstractDict=Dict{String,Function}(),
                      metadata::AbstractDict=Dict{String,Any}())
    model_name = String(name)
    isempty(strip(model_name)) && throw(ArgumentError("Model adapter name must be non-empty."))
    all(input -> input isa CalibrationInput, calibration_inputs) ||
        throw(ArgumentError("Each calibration input must be a CalibrationInput."))
    all(indicator -> indicator isa ResultIndicator, indicators) ||
        throw(ArgumentError("Each result indicator must be a ResultIndicator."))
    _validate_unique_names(calibration_inputs, "calibration input")
    _validate_unique_names(indicators, "result indicator")

    return ModelAdapter(
        model_name,
        String(description),
        version === nothing ? nothing : String(version),
        _compatibility_index(compatibility),
        _as_build_callback(model),
        CalibrationInput[input for input in calibration_inputs],
        calibrate,
        check_calibration,
        _workflow_index(scenarios, "scenario"),
        _workflow_index(experiments, "experiment"),
        ResultIndicator[indicator for indicator in indicators],
        _reporter_index(reporters),
        _transport_dict(metadata, "Model metadata"),
    )
end

"""
    build_model(adapter; calibration=nothing)

Invoke the model-owned build callback. When a calibration artifact is supplied,
one-argument builders receive it; zero-argument builders remain supported for
legacy and self-contained models. The returned object is validated by the solve
action, which is the layer that depends on JCGECore.
"""
function build_model(adapter::ModelAdapter; calibration=nothing)
    calibration !== nothing && applicable(adapter.build, calibration) &&
        return adapter.build(calibration)
    return adapter.build()
end

"""
    calibration_input_status(adapter, inputs)

Check that all calibration inputs declared as required by `adapter` are present
in `inputs`. This only validates the contract boundary: it does not load data,
call calibration code, or reject model-owned optional inputs.
"""
function calibration_input_status(adapter::ModelAdapter, inputs::AbstractDict)
    provided = _registered_input_names(inputs)
    required = [input.name for input in adapter.calibration_inputs if input.required]
    missing = sort([name for name in required if !(name in provided)])
    return Dict(
        :valid => isempty(missing),
        :required => sort(required),
        :provided => sort(collect(provided)),
        :missing => missing,
    )
end

"""
    calibration_diagnostics(adapter, artifact)

Run the model-owned calibration-check callback, if declared, and convert its
result to transport-safe data. A model without a check callback returns
`nothing`.
"""
function calibration_diagnostics(adapter::ModelAdapter, artifact)
    adapter.check_calibration === nothing && return nothing
    return _transport_value(adapter.check_calibration(artifact), "Calibration diagnostics")
end

function _parameter_type_matches(value, expected::AbstractString)
    expected == "string" && return value isa AbstractString
    expected == "number" && return value isa Number && !(value isa Bool)
    expected == "integer" && return value isa Integer && !(value isa Bool)
    expected == "boolean" && return value isa Bool
    expected == "object" && return value isa AbstractDict
    expected == "array" && return value isa AbstractVector
    expected == "null" && return value === nothing
    return true
end

"""
    workflow_parameter_status(workflow, parameters)

Check required and primitive type declarations in a workflow's parameter
metadata. Undeclared parameters remain visible to the model callback, allowing
model packages to evolve their own structured inputs without arbitrary code.
"""
function workflow_parameter_status(workflow::WorkflowAdapter, parameters::AbstractDict)
    supplied = Dict{String,Any}(string(key) => value for (key, value) in parameters)
    missing = String[]
    invalid = Dict{String,String}()
    for (name, schema) in workflow.parameters
        schema isa AbstractDict || continue
        required = get(schema, "required", false)
        if required && !haskey(supplied, name)
            push!(missing, name)
            continue
        end
        haskey(supplied, name) || continue
        expected = get(schema, "type", nothing)
        expected isa AbstractString || continue
        _parameter_type_matches(supplied[name], expected) ||
            (invalid[name] = "expected $(expected), received $(typeof(supplied[name]))")
    end
    return Dict(
        :valid => isempty(missing) && isempty(invalid),
        :provided => sort(collect(keys(supplied))),
        :missing => sort(missing),
        :invalid => invalid,
    )
end

"""
    run_workflow(workflow, state, parameters)

Run a registered, model-owned scenario or experiment callback and return both
the raw result for context retention and its transport-safe representation.
"""
function run_workflow(workflow::WorkflowAdapter, state::WorkflowState, parameters::AbstractDict)
    result = workflow.run(state, parameters)
    return result, _transport_value(result, "Workflow result")
end

"""
    run_reporter(adapter, name, source)

Run one named model-owned reporter with a solved result or workflow result as
its source. Returns both the raw report for context retention and a
transport-safe representation for MCP responses.
"""
function run_reporter(adapter::ModelAdapter, name::AbstractString, source)
    reporter = get(adapter.reporters, String(name), nothing)
    reporter === nothing && throw(ArgumentError("Model $(adapter.name) does not declare reporter $(name)."))
    report = reporter(source)
    return report, _transport_value(report, "Reporter output")
end

function _package_version(value, package_name::AbstractString)
    value isa VersionNumber && return value
    value isa AbstractString ||
        throw(ArgumentError("Version supplied for $(package_name) must be a VersionNumber or version string."))
    try
        return VersionNumber(value)
    catch error
        throw(ArgumentError("Invalid installed version $(value) for $(package_name): $(sprint(showerror, error))"))
    end
end

"""
    compatibility_status(adapter, versions)

Evaluate declared package compatibility against caller-supplied package
versions. The interface deliberately does not inspect or modify Julia's active
environment: the server host supplies the resolved package versions it wants
to assess.
"""
function compatibility_status(adapter::ModelAdapter, versions::AbstractDict)
    available = Dict{String,Any}(string(name) => version for (name, version) in versions)
    entries = Dict{Symbol,Any}[]
    for package_name in sort(collect(keys(adapter.compatibility)))
        requirement = adapter.compatibility[package_name]
        if !haskey(available, package_name)
            push!(entries, Dict(
                :package => package_name,
                :requirement => requirement,
                :installed => nothing,
                :status => "missing",
            ))
            continue
        end
        installed = _package_version(available[package_name], package_name)
        compatible = installed in Pkg.Types.VersionSpec(requirement)
        push!(entries, Dict(
            :package => package_name,
            :requirement => requirement,
            :installed => string(installed),
            :status => compatible ? "compatible" : "incompatible",
        ))
    end
    return Dict(
        :compatible => all(entry[:status] == "compatible" for entry in entries),
        :packages => entries,
    )
end

function _input_summary(input::CalibrationInput)
    return Dict(
        :name => input.name,
        :description => input.description,
        :required => input.required,
        :schema => input.schema,
    )
end

function _workflow_summary(workflow::WorkflowAdapter)
    return Dict(
        :name => workflow.name,
        :description => workflow.description,
        :parameters => workflow.parameters,
    )
end

function _indicator_summary(indicator::ResultIndicator)
    return Dict(
        :name => indicator.name,
        :description => indicator.description,
        :unit => indicator.unit,
    )
end

"""
    adapter_summary(adapter)

Return transport-safe metadata for discovery tools. Callback functions are not
included in the result.
"""
function adapter_summary(adapter::ModelAdapter)
    return Dict(
        :name => adapter.name,
        :description => adapter.description,
        :version => adapter.version,
        :compatibility => adapter.compatibility,
        :calibration_inputs => [_input_summary(input) for input in adapter.calibration_inputs],
        :calibration => Dict(
            :available => adapter.calibrate !== nothing,
            :check_available => adapter.check_calibration !== nothing,
            :required_inputs => sort([input.name for input in adapter.calibration_inputs if input.required]),
        ),
        :scenarios => [_workflow_summary(adapter.scenarios[name]) for name in sort(collect(keys(adapter.scenarios)))],
        :experiments => [_workflow_summary(adapter.experiments[name]) for name in sort(collect(keys(adapter.experiments)))],
        :indicators => [_indicator_summary(indicator) for indicator in adapter.indicators],
        :reporters => sort(collect(keys(adapter.reporters))),
        :capabilities => Dict(
            :build => true,
            :calibrate => adapter.calibrate !== nothing,
            :check_calibration => adapter.check_calibration !== nothing,
            :scenarios => !isempty(adapter.scenarios),
            :experiments => !isempty(adapter.experiments),
            :reporters => !isempty(adapter.reporters),
        ),
        :metadata => adapter.metadata,
    )
end

end # module
