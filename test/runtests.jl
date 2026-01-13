using JCGEAgentInterface
using Test

@testset "JCGEAgentInterface" begin
    req = request("1", :list_packages)
    ok, _ = JCGEAgentInterface.Schema.validate_request(req)
    @test ok

    bad = request("2", :load_model)
    ok_bad, _ = JCGEAgentInterface.Schema.validate_request(bad)
    @test !ok_bad
end
