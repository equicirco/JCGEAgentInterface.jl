FROM docker.io/library/julia:1.10

ARG VERSION=0.1.1

LABEL org.opencontainers.image.title="JCGE Agent Interface MCP Server"
LABEL org.opencontainers.image.description="Model Context Protocol server for discovering, guiding, solving, validating, and rendering JCGE CGE models."
LABEL org.opencontainers.image.source="https://github.com/equicirco/JCGEAgentInterface.jl"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL io.modelcontextprotocol.server.name="io.github.equicirco/JCGEAgentInterface.jl"

ENV JULIA_DEPOT_PATH=/julia_depot

WORKDIR /app

COPY Project.toml /app/
COPY src /app/src

RUN julia --project=/app -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

ENTRYPOINT ["julia", "--project=/app", "-e", "using JCGEAgentInterface; serve(transport=:mcp_stdio)"]
