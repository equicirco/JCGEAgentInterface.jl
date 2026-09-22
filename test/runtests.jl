using JCGEAgentInterface
using Test

@testset "JCGEAgentInterface" begin
    adapter = ModelAdapter(
        "contract-model",
        () -> :model_spec;
        description="A model-owned adapter contract fixture.",
        version="1.2.3",
        compatibility=Dict("JCGECore" => "0.1"),
        calibration_inputs=[CalibrationInput("sam"; description="Balanced social accounting matrix.")],
        calibrate=inputs -> (:calibrated, inputs),
        check_calibration=artifact -> Dict(:ok => artifact !== nothing),
        scenarios=[WorkflowAdapter(
            "reference",
            (state, parameters) -> Dict(:calibrated => state.calibration_available, :parameters => parameters);
            description="Reference scenario.",
        )],
        experiments=[WorkflowAdapter(
            "elasticity-grid",
            (state, parameters) -> Dict(:model => state.model_name, :elasticity => parameters[:elasticity]);
            parameters=Dict("elasticity" => Dict("type" => "number", "required" => true)),
        )],
        indicators=[ResultIndicator("real_gdp"; unit="index")],
        reporters=Dict("summary" => result -> result),
        metadata=Dict("source" => "test"),
    )
    contract = adapter_summary(adapter)
    @test contract[:name] == "contract-model"
    @test contract[:calibration][:available]
    @test contract[:calibration][:required_inputs] == ["sam"]
    @test contract[:capabilities][:experiments]
    @test contract[:scenarios][1][:name] == "reference"
    @test contract[:reporters] == ["summary"]
    @test build_model(adapter) == :model_spec
    calibrated_builder = ModelAdapter("artifact-builder", artifact -> artifact)
    @test build_model(calibrated_builder; calibration=:calibrated_spec) == :calibrated_spec

    input_status = calibration_input_status(adapter, Dict(:sam => "balanced-sam", :optional => "retained"))
    @test input_status[:valid]
    @test input_status[:missing] == String[]
    missing_input_status = calibration_input_status(adapter, Dict(:optional => "retained"))
    @test !missing_input_status[:valid]
    @test missing_input_status[:missing] == ["sam"]

    compatible = compatibility_status(adapter, Dict("JCGECore" => v"0.1.4"))
    @test compatible[:compatible]
    @test compatible[:packages][1][:status] == "compatible"
    incompatible = compatibility_status(adapter, Dict("JCGECore" => "0.2.0"))
    @test !incompatible[:compatible]
    @test incompatible[:packages][1][:status] == "incompatible"
    missing_package = compatibility_status(adapter, Dict())
    @test !missing_package[:compatible]
    @test missing_package[:packages][1][:status] == "missing"

    @test_throws ArgumentError ModelAdapter("invalid-metadata", :model; metadata=Dict("callback" => identity))
    @test_throws ArgumentError ModelAdapter("invalid-compatibility", :model; compatibility=Dict("JCGECore" => "not a version"))

    adapter_ctx = AgentContext()
    register_model!(adapter_ctx, adapter)
    @test model_names(adapter_ctx) == ["contract-model"]
    @test model_adapter(adapter_ctx, "contract-model") === adapter
    @test_throws ArgumentError register_model!(adapter_ctx, adapter)
    register_model!(adapter_ctx, "legacy-model", :legacy_spec)
    @test build_model(model_adapter(adapter_ctx, "legacy-model")) == :legacy_spec
    legacy_context = AgentContext(models=Dict("legacy-constructor" => () -> :legacy_constructor_spec))
    @test model_names(legacy_context) == ["legacy-constructor"]
    @test build_model(model_adapter(legacy_context, "legacy-constructor")) == :legacy_constructor_spec

    load_contract = handle_request(request("adapter-load", :load_model; payload=Dict(:name => "contract-model")); ctx=adapter_ctx)
    @test load_contract.ok
    @test load_contract.data[:model][:version] == "1.2.3"
    @test active_model_adapter(adapter_ctx) === adapter

    calibration = handle_request(request("adapter-calibration", :calibrate_model; payload=Dict(:inputs => Dict(:sam => "balanced-sam"))); ctx=adapter_ctx)
    @test calibration.ok
    @test calibration.data[:model] == "contract-model"
    @test calibration.data[:calibration][:completed]
    @test adapter_ctx.calibration_model == "contract-model"
    @test adapter_ctx.last_calibration[1] == :calibrated
    @test adapter_ctx.last_spec === nothing
    @test adapter_ctx.last_result === nothing

    checked_calibration = handle_request(request("adapter-calibration-check", :check_calibration); ctx=adapter_ctx)
    @test checked_calibration.ok
    @test checked_calibration.data[:diagnostics][:ok]
    missing_calibration = handle_request(request("missing-calibration", :calibrate_model; payload=Dict(:inputs => Dict())); ctx=adapter_ctx)
    @test !missing_calibration.ok
    @test occursin("sam", missing_calibration.error)

    scenario = handle_request(request("reference-scenario", :run_scenario; payload=Dict(:name => "reference")); ctx=adapter_ctx)
    @test scenario.ok
    @test scenario.data[:workflow][:kind] == "scenario"
    @test scenario.data[:result][:calibrated]
    @test adapter_ctx.workflow_name == "reference"
    @test adapter_ctx.last_workflow[:calibrated]

    experiment = handle_request(request("elasticity-experiment", :run_experiment; payload=Dict(:name => "elasticity-grid", :parameters => Dict(:elasticity => 2.0))); ctx=adapter_ctx)
    @test experiment.ok
    @test experiment.data[:workflow][:kind] == "experiment"
    @test experiment.data[:result][:elasticity] == 2.0
    @test adapter_ctx.workflow_kind == :experiment
    invalid_experiment = handle_request(request("invalid-experiment", :run_experiment; payload=Dict(:name => "elasticity-grid", :parameters => Dict(:elasticity => "two"))); ctx=adapter_ctx)
    @test !invalid_experiment.ok
    @test occursin("elasticity", invalid_experiment.error)

    reported = handle_request(request("experiment-report", :run_reporter; payload=Dict(:name => "summary")); ctx=adapter_ctx)
    @test reported.ok
    @test reported.data[:source] == "workflow"
    @test reported.data[:report][:elasticity] == 2.0
    @test reported.data[:indicators][1][:name] == "real_gdp"
    @test adapter_ctx.report_name == "summary"
    @test adapter_ctx.last_report[:model] == "contract-model"

    refreshed_calibration = handle_request(request("refresh-calibration", :calibrate_model; payload=Dict(:inputs => Dict(:sam => "balanced-sam"))); ctx=adapter_ctx)
    @test refreshed_calibration.ok
    @test adapter_ctx.last_workflow === nothing
    @test adapter_ctx.last_report === nothing

    records = provenance_records(adapter_ctx)
    @test records[1]["record_id"] == "record-000001"
    @test records[1]["model_version"] == "1.2.3"
    @test records[1]["recorded_at_unix"] isa Real
    @test any(record -> record["event"] == "calibrated", records)
    @test any(record -> record["event"] == "experiment", records)
    calibration_record = first(filter(record -> record["event"] == "calibrated", records))
    @test calibration_record["details"]["inputs"]["sam"] == "balanced-sam"
    selected_record = provenance_records(adapter_ctx; record_id="record-000001")
    @test selected_record["event"] == "model_loaded"
    provenance = handle_request(request("provenance", :provenance); ctx=adapter_ctx)
    @test provenance.ok
    @test length(provenance.data[:records]) == length(records)

    status = handle_request(request("model-status", :model_status); ctx=adapter_ctx)
    @test status.ok
    @test status.data[:model] == "contract-model"
    @test status.data[:compatibility][:compatible]
    @test status.data[:calibration][:available]
    @test !status.data[:workflow][:available]
    @test !status.data[:solve][:available]
    @test "jcge_run_scenario" in status.data[:next_actions]
    @test "jcge_provenance" in status.data[:next_actions]

    registered_models = handle_request(request("adapter-list", :list_packages); ctx=adapter_ctx)
    @test registered_models.ok
    @test registered_models.data[:models] == ["contract-model", "legacy-model"]
    @test registered_models.data[:active_model] == "contract-model"
    @test length(registered_models.data[:model_adapters]) == 2
    @test registered_models.data[:model_adapters][1][:name] == "contract-model"
    @test registered_models.data[:model_adapters][1][:capabilities][:calibrate]
    @test registered_models.data[:model_adapters][1][:compatibility_status][:packages][1][:status] == "compatible"

    req = request("1", :list_packages)
    ok, _ = JCGEAgentInterface.Schema.validate_request(req)
    @test ok

    bad = request("2", :load_model)
    ok_bad, _ = JCGEAgentInterface.Schema.validate_request(bad)
    @test !ok_bad

    caps = handle_request(request("3", :capabilities))
    @test caps.ok
    @test haskey(caps.data, :packages)
    @test any(pkg -> pkg[:name] == "JCGECore", caps.data[:packages])
    @test any(pkg -> pkg[:name] == "JCGEImportData", caps.data[:packages])
    @test any(pkg -> pkg[:name] == "JCGEExamples", caps.data[:packages])

    blocks = handle_request(request("4", :list_blocks; payload=Dict(:group => "production")))
    @test blocks.ok
    @test !isempty(blocks.data[:blocks])
    @test all(entry -> entry[:group] == "production", blocks.data[:blocks])

    desc = handle_request(request("5", :describe_block; payload=Dict(:name => "production")))
    @test desc.ok
    @test desc.data[:block][:helper] == "production"

    guide = handle_request(request("6", :modeling_guide))
    @test guide.ok
    @test haskey(guide.data, :workflow)

    formulation = handle_request(request("6a", :formulation_guide))
    @test formulation.ok
    @test haskey(formulation.data, :choices)
    @test any(choice -> choice[:formulation] == "mixed complementarity problem", formulation.data[:choices])

    solver = handle_request(request("6b", :solver_guide; payload=Dict(:formulation => "mcp")))
    @test solver.ok
    @test any(item -> item[:name] == "PATHSolver", solver.data[:optional_solver_status])

    import_guide = handle_request(request("6b-import", :import_data_guide))
    @test import_guide.ok
    @test import_guide.data[:package] == "JCGEImportData"
    @test any(source -> source[:source] == "Eurostat FIGARO", import_guide.data[:available_sources])

    calibration = handle_request(request("6c", :calibration_guide))
    @test calibration.ok
    @test haskey(calibration.data[:available_today], :canonical_files)
    @test calibration.data[:package] == "JCGECalibrate"

    reporting = handle_request(request("6d", :reporting_guide))
    @test reporting.ok
    @test any(contains("render_equations"), reporting.data[:jcge_output_available_today])

    examples = handle_request(request("6e", :list_examples))
    @test examples.ok
    @test examples.data[:package] == "JCGEExamples"
    @test any(example -> example[:name] == "GTAP7", examples.data[:examples])
    @test any(example -> example[:name] == "GTAP7MCP", examples.data[:examples])

    status = handle_request(request("7", :package_status))
    @test status.ok
    @test haskey(status.data, :packages)

    dry_update = handle_request(request("8", :update_packages))
    @test dry_update.ok
    @test dry_update.data[:mode] == "dry_run"

    server = MCPServer()
    init = handle_mcp_message(server, Dict(
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => Dict("protocolVersion" => "2025-11-25"),
    ))
    @test length(init) == 1
    @test init[1]["result"]["protocolVersion"] == "2025-11-25"

    tools = handle_mcp_message(server, Dict(
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/list",
    ))
    @test any(tool -> tool["name"] == "jcge_capabilities", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_formulation_guide", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_import_data_guide", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_calibration_guide", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_list_examples", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_calibrate_model", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_run_scenario", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_run_reporter", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_provenance", tools[1]["result"]["tools"])
    @test any(tool -> tool["name"] == "jcge_model_status", tools[1]["result"]["tools"])
    tool_names = Set(tool["name"] for tool in tools[1]["result"]["tools"])
    tool_actions = JCGEAgentInterface.Catalog.MCP_TOOL_ACTIONS
    @test tool_names == Set(keys(tool_actions))
    handlers = default_handlers()
    @test all(action -> haskey(handlers, action), values(tool_actions))

    mcp_ctx = AgentContext()
    register_model!(mcp_ctx, adapter)
    model_server = MCPServer(ctx=mcp_ctx)
    model_init = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "initialize",
        "params" => Dict("protocolVersion" => "2025-11-25"),
    ))
    @test length(model_init) == 1
    listed_models = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 5,
        "method" => "tools/call",
        "params" => Dict("name" => "jcge_list_models", "arguments" => Dict()),
    ))
    @test listed_models[1]["result"]["isError"] == false
    listed_content = listed_models[1]["result"]["structuredContent"]
    @test listed_content["active_model"] === nothing
    @test listed_content["model_adapters"][1]["name"] == "contract-model"

    loaded_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 51,
        "method" => "tools/call",
        "params" => Dict(
            "name" => "jcge_load_model",
            "arguments" => Dict("name" => "contract-model"),
        ),
    ))
    @test loaded_model[1]["result"]["isError"] == false
    @test loaded_model[1]["result"]["structuredContent"]["model"]["name"] == "contract-model"

    calibrated_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 6,
        "method" => "tools/call",
        "params" => Dict(
            "name" => "jcge_calibrate_model",
            "arguments" => Dict("inputs" => Dict("sam" => "balanced-sam")),
        ),
    ))
    @test calibrated_model[1]["result"]["isError"] == false
    @test calibrated_model[1]["result"]["structuredContent"]["calibration"]["completed"] == true

    checked_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 61,
        "method" => "tools/call",
        "params" => Dict("name" => "jcge_check_calibration", "arguments" => Dict()),
    ))
    @test checked_model[1]["result"]["isError"] == false
    @test checked_model[1]["result"]["structuredContent"]["diagnostics"]["ok"] == true

    scenario_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 7,
        "method" => "tools/call",
        "params" => Dict(
            "name" => "jcge_run_scenario",
            "arguments" => Dict("name" => "reference"),
        ),
    ))
    @test scenario_model[1]["result"]["isError"] == false
    @test scenario_model[1]["result"]["structuredContent"]["result"]["calibrated"] == true

    reported_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 8,
        "method" => "tools/call",
        "params" => Dict(
            "name" => "jcge_run_reporter",
            "arguments" => Dict("name" => "summary"),
        ),
    ))
    @test reported_model[1]["result"]["isError"] == false
    @test reported_model[1]["result"]["structuredContent"]["source"] == "workflow"

    provenance_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 9,
        "method" => "tools/call",
        "params" => Dict("name" => "jcge_provenance", "arguments" => Dict()),
    ))
    @test provenance_model[1]["result"]["isError"] == false
    @test !isempty(provenance_model[1]["result"]["structuredContent"]["records"])

    status_model = handle_mcp_message(model_server, Dict(
        "jsonrpc" => "2.0",
        "id" => 10,
        "method" => "tools/call",
        "params" => Dict("name" => "jcge_model_status", "arguments" => Dict()),
    ))
    @test status_model[1]["result"]["isError"] == false
    @test status_model[1]["result"]["structuredContent"]["calibration"]["available"] == true

    call = handle_mcp_message(server, Dict(
        "jsonrpc" => "2.0",
        "id" => 3,
        "method" => "tools/call",
        "params" => Dict("name" => "jcge_modeling_guide", "arguments" => Dict()),
    ))
    @test call[1]["result"]["isError"] == false
    @test haskey(call[1]["result"]["structuredContent"], "workflow")
end
