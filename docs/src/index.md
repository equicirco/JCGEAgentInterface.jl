# JCGEAgentInterface

```@raw html
<picture>
  <source srcset="assets/jcge_agentinterface_logo_dark.png" media="(prefers-color-scheme: dark)">
  <img src="assets/jcge_agentinterface_logo_light.png" alt="JCGEAgentInterface" style="max-width: 200px; height: auto;">
</picture>
```

`JCGEAgentInterface` is part of the [JCGE](https://jcge.org) ecosystem. This page provides the package
overview and entry points; the API reference is on the API page.

It exposes both the original JCGE action protocol and a standard MCP stdio
server. Agents can use it to discover JCGE package capabilities, inspect the
available block catalog, guide model development, solve registered models,
validate solved contexts, and render implemented equations through `JCGEOutput`.

For an MCP server to calibrate or study a particular model, that model opts in
through the explicit [model integration contract](model-integration.md). Models
that do not opt in continue to support loading and solving through the legacy
registration form.

The [Agent Services](services.md) page summarizes the service categories and
current limits.
