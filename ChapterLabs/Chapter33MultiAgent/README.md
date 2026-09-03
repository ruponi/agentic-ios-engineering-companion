# Chapter 33: Beyond One Agent

This lab registers a route-planning specialist through the existing read-only
`AgentTool` contract. It proves that provenance, turn limits, and host-minted
approval remain outer-loop responsibilities, and that parent and child turns
share one finite tree budget.

`swift test` runs the deterministic invariant suite. `swift run MultiAgentTrace`
prints the successful specialist trace and the clean tree-budget exhaustion.
