## *PROMPT*

> Please remove these flows: "Sales", "Scheduling", "Billing" and "Support".

## *ANSWER*

> Before I delete these, I want to flag that the Router currently routes messages to these 4 flows via Execute Workflow nodes and the LLM classifies into their categories (support, sales, scheduling, billing).
>
> Deleting just the workflows will cause the Router to error when it tries to execute them. Should I also:
>
> 1. Remove the Execute Workflow nodes and Switch routes from the Router that reference these flows?
> 2. Remove their categories from the LLM prompt so the LLM stops classifying into them?
> 3. Or should those categories redirect somewhere else (e.g., human) instead of being removed?

---

# Plan: Remove Support, Sales, Scheduling, and Billing Flows

## Context

The user wants to remove 4 sub-flows (Support, Sales, Scheduling, Billing) and their LLM categories entirely. The LLM will no longer classify into these categories — messages that would have matched them will now fall into `human` or `unclear` naturally. After this change, the Router classifies into 3 categories: `certification`, `human`, `unclear`.

## Step 1: Update Router Workflow (`bS0Mog4nsCyAT7Ao`)

Single `n8n_update_partial_workflow` call with operations in this order:

### 1a. Remove All Connections from Both Switch Nodes

This must happen **FIRST** because updating Switch rules changes output indices, which would break existing connections.

**From "Route by Classification" (`switch-class`)** — 7 `removeConnection` ops:

- → Execute WF - Support
- → Execute WF - Sales
- → Execute WF - Scheduling
- → Execute WF - Billing
- → Execute WF - Human
- → Execute WF - Certification
- → OK
- → Handle Unclear Intent

**From "Route by active_flow" (`switch-flow`)** — 7 `removeConnection` ops:

- → Execute WF - Support
- → Execute WF - Sales
- → Execute WF - Scheduling
- → Execute WF - Billing
- → Execute WF - Human
- → Execute WF - Certification
- → Load Last 10 Messages

### 1b. Update Both Switch Nodes with Fewer Rules

**"Route by Classification" (`switch-class`)** — new rules:

| Index | Rule | Output Key |
|---|---|---|
| 0 | `route === "human"` | `human` |
| 1 | `route === "certification"` | `certification` |
| 2 | `route === "unclear"` | `unclear` |
| 3 | fallback (extra) | — |

**"Route by active_flow" (`switch-flow`)** — new rules:

| Index | Rule | Output Key |
|---|---|---|
| 0 | `active_flow === "human"` | `human` |
| 1 | `active_flow === "certification"` | `certification` |
| 2 | fallback (extra) | — |

### 1c. Remove 4 Execute Workflow Nodes

- `exec-support` (Execute WF - Support)
- `exec-sales` (Execute WF - Sales)
- `exec-scheduling` (Execute WF - Scheduling)
- `exec-billing` (Execute WF - Billing)

This also auto-removes their connections to OK.

### 1d. Add New Connections with Correct Indices

**From "Route by Classification":**

- Output 0 → Execute WF - Human (`sourceIndex: 0`)
- Output 1 → Execute WF - Certification (`sourceIndex: 1`)
- Output 2 → OK (`sourceIndex: 2`)
- Output 2 → Handle Unclear Intent (`sourceIndex: 2`)

**From "Route by active_flow":**

- Output 0 → Execute WF - Human (`sourceIndex: 0`)
- Output 1 → Execute WF - Certification (`sourceIndex: 1`)
- Output 2 → Load Last 10 Messages (`sourceIndex: 2`)

### 1e. Update "Build LLM Prompt" (`code-prompt`)

Remove support/sales/scheduling/billing from the `systemPrompt`. New categories:

- **certification:** certificação digital, código, renovação, suporte técnico
- **human:** quando nenhuma categoria se aplica ou usuário pede atendente
- **unclear:** saudações simples (oi, olá, bom dia), mensagens vagas sem intenção clara

### 1f. Check & Update "Parse LLM Response" (`code-parse`)

If it has a `validRoutes` array, remove the 4 categories. Need to extract this node's code first during implementation.

### 1g. Optional: Reposition Remaining Execute Nodes

Move Human and Certification up to fill the vertical gap.

## Step 2: Delete the 4 Sub-Workflows

4 separate `n8n_delete_workflow` calls:

- `et7ob9TmlY7re17H` (Support)
- `dlgNK7lJcmnwlXBO` (Sales)
- `81SWldP39P6haTgM` (Scheduling)
- `rVLdFwLTDpamP9QN` (Billing)

## Step 3: Update Documentation

- Update `docs/NOTES.md`: remove references to the 4 flows, update architecture tree and category lists
- Update memory files if needed

## Verification

1. `n8n_validate_workflow` on Router (`bS0Mog4nsCyAT7Ao`)
2. `n8n_list_workflows` — confirm only 7 workflows remain
3. Verify both Switch nodes have correct rule count and connections via `n8n_get_workflow` structure mode
