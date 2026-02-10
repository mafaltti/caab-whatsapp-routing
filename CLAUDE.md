# CAAB WhatsApp Routing — n8n Workflow Project

## Project Overview

This is an **n8n workflow development project** for CAAB WhatsApp routing. Claude's role is to build, modify, and maintain n8n workflows on a self-hosted n8n instance.

- **Platform:** Self-hosted n8n
- **Domain:** WhatsApp message routing for CAAB
- **Primary workflow:** Claude Code acts as the workflow builder/maintainer

## Available Tools

### n8n MCP Server

Direct interaction with the n8n instance via MCP tools, organized by category:

**Node Discovery & Documentation:**
- `searchNodes` — Find nodes by keyword (e.g., "slack", "webhook")
- `listNodes` — List all available node types
- `getNodeInfo` — Get node configuration details (use `detail: "standard"` for 95% of cases)
- `getNodeEssentials` — Quick reference for a node's key properties
- `getNodeDocumentation` — Full documentation for a node
- `searchNodeProperties` — Search for specific properties within a node
- `listAITools` — List available AI/LangChain tool nodes

**Validation:**
- `validateNodeOperation` — Validate a single node's operation config
- `validateNodeMinimal` — Quick minimal validation of node config
- `validateWorkflow` — Validate an entire workflow structure

**Workflow Management:**
- `n8n_create_workflow` — Create a new workflow
- `n8n_update_partial_workflow` — Update specific parts of a workflow (preferred — 99% success rate)
- `n8n_update_full_workflow` — Replace entire workflow definition
- `n8n_delete_workflow` — Delete a workflow
- `n8n_get_workflow` — Get workflow by ID
- `n8n_list_workflows` — List all workflows on the instance
- `n8n_activate_workflow` / `n8n_deactivate_workflow` — Toggle workflow active state
- `n8n_execute_workflow` — Execute a workflow for testing

**Templates:**
- `listTemplates` — Browse available workflow templates
- `searchTemplates` — Search templates by keyword
- `deployTemplate` — Deploy a template as a new workflow
- `validateTemplate` — Validate a template before deployment

**Database:**
- `getDatabaseStatistics` — Get n8n instance database stats

### n8n Skills (Auto-Activating)

Seven skills activate automatically based on query content — no manual invocation needed:

1. **Expression Syntax** — n8n expression language rules and patterns
2. **MCP Tools Expert** — Best practices for using MCP tools effectively
3. **Workflow Patterns** — Architectural patterns for common workflow types
4. **Validation Expert** — Iterative validation and error resolution
5. **Node Configuration** — Correct node setup and parameter configuration
6. **Code JavaScript** — JavaScript Code node conventions and patterns
7. **Code Python** — Python Code node usage (when JS isn't sufficient)

## MCP Tool Usage Patterns

### Preferred Workflow for Building Nodes
1. `searchNodes` → find the right node type
2. `getNodeInfo` (detail: "standard") → understand its configuration
3. Configure the node in the workflow
4. `validateNodeOperation` → validate the config
5. Fix issues → re-validate (2-3 cycles is typical)
6. `n8n_update_partial_workflow` → deploy the changes

### nodeType Format Distinction
- **Discovery/validation tools:** Use short format — `nodes-base.slack`, `nodes-base.webhook`
- **Workflow management tools:** Use full format — `n8n-nodes-base.slack`, `n8n-nodes-base.webhook`

### Key Conventions
- **Always prefer `n8n_update_partial_workflow`** over `n8n_update_full_workflow` — safer and higher success rate
- **Validation profile:** Use `"runtime"` (recommended) over `"strict"`
- **Detail level:** Use `"standard"` for `getNodeInfo` in 95% of cases; use `"full"` only when you need every property
- **Iterative validation:** Build → validate → fix → re-validate is the normal cycle

## Code Node Conventions

### JavaScript (Default — Use for 95% of Code Nodes)
- **Always return** `[{json: {...}}]` format (array of objects with `json` key)
- **Data access:**
  - `$input.all()` — batch processing (default mode)
  - `$input.first()` — single item access
  - `$input.item` — only in "Run Once for Each Item" mode
- **Webhook data** lives under `.body`, not at root: `$input.first().json.body`
- **No external packages** — only built-in Node.js APIs available

### Python (Only When Needed)
Use Python only when you need standard library functions not easily available in JS (regex, hashlib, statistics). No external packages available.

### Top Mistakes to Avoid
- Missing `return` statement — node produces no output silently
- Using `{{ }}` expression syntax inside Code nodes — use plain JS/Python instead
- Returning plain objects instead of `[{json: {...}}]` array format
- Missing null/undefined checks on input data
- Accessing webhook data at root instead of under `.body`

## Expression Syntax Rules

- **Double curly braces:** `{{ expression }}` — used in node parameter fields (NOT in Code nodes)
- **Core variables:** `$json`, `$node["Node Name"]`, `$now`, `$env`, `$execution`
- **Bracket notation** for names with spaces: `$node["Node Name"].json["field name"]`
- **Case-sensitive** node name matching — must match exactly
- **Webhook data** always under `.body`: `{{ $json.body.message }}`

## Safety Rules

- **NEVER edit production workflows directly** — always make a copy first
- **Test in development environment** before deploying to production
- **Export/backup workflows** before making significant changes
- Use `n8n_get_workflow` to fetch current state before modifying

## Workflow Quality Standards

### Error Handling
- Every workflow **must** include error handling — use an Error Trigger node or try/catch patterns on critical nodes
- Never leave a workflow without a way to surface failures

### Naming Conventions
- **Workflows:** Descriptive names prefixed with context — e.g., `[WhatsApp] Route Incoming Message`, `[WhatsApp] Send Confirmation Reply`
- **Nodes:** Names must clearly describe their action — e.g., `Check Message Type`, `Route to Support Queue`, `Format Reply Payload`
- Avoid default node names like `IF`, `Code`, `HTTP Request`

### Documentation (Sticky Notes)
- Add sticky notes to document:
  - Workflow purpose and high-level logic
  - Important decision points or business rules
  - External dependencies (APIs, credentials, webhooks)

### Node Organization
- Logical **left-to-right** flow
- Group related nodes visually
- Keep workflows clean and readable — avoid spaghetti connections

### Testing & Validation
- Always test workflows after creation using `n8n_execute_workflow`
- Run `validateWorkflow` after building or modifying workflows
- Verify both success and error paths when possible
- Follow the iterative cycle: build → validate → fix → re-validate

### Idempotency
- Design workflows to handle duplicate messages gracefully
- Use message IDs or timestamps to detect and skip duplicates where applicable

## WhatsApp Routing Conventions

### Message Receiving
- Use webhook triggers for incoming WhatsApp messages
- Validate incoming payload structure early in the workflow

### Routing Logic
- Use **Switch** nodes with clear, named conditions for message routing
- Document routing rules in sticky notes next to Switch nodes
- Keep routing conditions explicit — avoid catch-all branches without logging

### Response Formatting
- Standardize response payloads before sending
- Include error/fallback responses for unrecognized message types

### Logging & Observability
- Log key routing decisions (which branch was taken, message type, sender)
- Include enough context in logs to debug issues without re-executing

## General Instructions

- **Always use `n8n_list_workflows`** to explore existing workflows before creating new ones
- **Prefer modifying** existing workflows over creating new ones when scope overlaps
- **Ask before deleting** or significantly restructuring existing workflows
- When in doubt about business logic or routing rules, ask the user before implementing assumptions
- **Recognize workflow architectural patterns:** webhook processing, HTTP API integration, database operations, AI agent workflows, scheduled tasks — and apply the appropriate pattern
