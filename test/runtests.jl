using JCGEAgentInterface
using Test

@testset "JCGEAgentInterface" begin
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

    calibration = handle_request(request("6c", :calibration_guide))
    @test calibration.ok
    @test haskey(calibration.data[:available_today], :canonical_files)
    @test calibration.data[:package] == "JCGECalibrate"

    reporting = handle_request(request("6d", :reporting_guide))
    @test reporting.ok
    @test any(contains("render_equations"), reporting.data[:jcge_output_available_today])

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
    @test any(tool -> tool["name"] == "jcge_calibration_guide", tools[1]["result"]["tools"])

    call = handle_mcp_message(server, Dict(
        "jsonrpc" => "2.0",
        "id" => 3,
        "method" => "tools/call",
        "params" => Dict("name" => "jcge_modeling_guide", "arguments" => Dict()),
    ))
    @test call[1]["result"]["isError"] == false
    @test haskey(call[1]["result"]["structuredContent"], "workflow")
end
