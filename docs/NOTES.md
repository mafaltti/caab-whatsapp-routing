# CAAB WhatsApp Routing — Project Notes

Key architectural decisions and operational details accumulated during development.

## Architecture

1 Router + 6 sub-flows + 3 cert sub-flows + 1 utility:

- **[WA] Router** — Receives incoming WhatsApp messages, classifies intent via LLM, routes to the appropriate sub-flow
- **[WA] Flow - Support** — Handles support-related messages
- **[WA] Flow - Sales** — Handles sales inquiries
- **[WA] Flow - Scheduling** — Handles appointment/scheduling requests
- **[WA] Flow - Billing** — Handles billing questions
- **[WA] Flow - Human** — Hands off to a human agent, then keeps the bot silent
- **[WA] Flow - Certificação Digital** — Mini-router for digital certificate requests (routes to Código/Renovação/Token)
- **[WA] Flow - Certificação Digital - Código** / **Renovação** / **Token** — Single-shot cert sub-flows
- **[WA] Flow - Close Chat** — Webhook utility for human agents to release a user back to the bot

## LLM Classification

- **Model:** Groq — Llama 3.3 70B Versatile (OpenAI-compatible API)
- **7 intent categories (Router):** `support`, `sales`, `scheduling`, `billing`, `certification`, `human`, `unclear`
- **4 sub-categories (Cert Digital):** `codigo`, `renovacao`, `token`, `unclear` (same LLM, separate prompt)
- **Always prefer LLM classification over keyword matching.** Keyword-based `String.includes()` checks are brittle and fail on natural language. LLM classification should be used whenever intent routing is needed.
- The `unclear` category catches greetings and vague messages — these do NOT trigger a sub-workflow
- On LLM failure, the router falls back to the `human` route

## Greeting Logic

The Caabot greeting/nudge is only sent on the **"unclear" intent path** (after LLM classification), not before classification. This avoids sending unnecessary greeting messages when the user's intent is already clear — e.g., if someone sends "I need to reschedule my appointment", they go straight to the Scheduling sub-flow without a generic "Hello! How can I help?" first.

Greeting dedup: the Compose Greeting node checks the last outbound message to avoid re-sending the same greeting.

## Groq API Key Rotation

Using 4 Groq API keys rotated randomly in the Build LLM Prompt node to stay within the free-tier rate limits:

- **Per key:** 30 RPM, 14,400 RPD
- **Effective (4 keys):** ~120 RPM, ~57,600 RPD

Keys are selected randomly at runtime — no round-robin state needed.

## Evolution API v1 → v2 Migration

Migrated from Evolution API v1 (1.8.6) to v2 (2.3.7) due to a critical limitation:

- **v1:** `remoteJid` can be a LID (Linked ID, `@lid` suffix) with **no way to resolve it to a phone number**. The `body.sender` field is the instance owner, not the message sender.
- **v2:** `remoteJid` **always contains the phone number**. LID is available separately in `remoteJidAlt`. Has an `addressingMode` field (`"pn"` or `"lid"`).

The v1 webhook is disabled; v2 is the active webhook source.

## Gemini → Groq Switch

Originally used Google Gemini for LLM classification, but the free tier quota was exhausted. Replaced with Groq because:

- OpenAI-compatible API (simpler integration via HTTP Request node)
- Clean JSON output (no markdown wrapping like Gemini sometimes produced)
- Generous free tier with key rotation (see above)

Response format changed from `item.candidates[0].content.parts[0].text` (Gemini) to `item.choices[0].message.content` (Groq/OpenAI).

## Certificação Digital — LLM Sub-Routing

The Certificação Digital flow acts as a mini-router. After sending a greeting menu ("código, renovação ou token?"), it classifies the user's reply to route to one of 3 cert sub-workflows or a nudge fallback.

Originally used **keyword matching** (`String.includes()` checks), which failed on natural language — e.g., "meu certificado vai vencer mês que vem" didn't match "renovação". Replaced with the **same Groq/Llama 3.3 70B LLM pattern** the main Router uses:

```
Build Cert LLM Prompt → LLM Classify Cert (HTTP/Groq) → Parse Cert Response → Route Cert Subroute
```

- **4 categories:** `codigo`, `renovacao`, `token`, `unclear`
- **Confidence guard:** < 0.7 → falls back to `unclear` (nudge re-ask), not `human`
- **LLM failure:** `continueOnFail` on HTTP node → Parse node detects missing `choices` → defaults to `unclear`
- Uses `$('Build Cert LLM Prompt').first().json` to recover original message data (Groq HTTP response doesn't pass through input)

## Human Agent Silent Mode

When a message is classified as `human`, the Human flow sends a greeting ("transferring you to an agent") and sets `step: "waiting"` in `conversation_state`. From that point on, the Router's **"Is Human Waiting?"** IF node intercepts all subsequent messages from that user and silently responds to the webhook — no bot reply is sent, so the human agent can converse without interference.

The inbound message is still saved to `chat_messages` (that happens before the state check), so nothing is lost.

### Releasing the user

The human agent calls the **Close Chat** webhook to clear the user's state:

```
GET https://n8n.arm03.danilocarneiro.com/webhook/close-chat?user_id=5511999999999
```

This deletes the `conversation_state` row. The user's next message is treated as a brand-new conversation (LLM classification from scratch).

If the agent forgets to call it, the state expires automatically after **30 minutes** (the standard `expires_at` TTL).

## Database

- **Provider:** Supabase Postgres (connected via session pooler, not the Supabase n8n node)
- **Tables:**
  - `conversation_state` — Tracks active conversation context per user
  - `chat_messages` — Stores message history for LLM context window
- **Schema:** Defined in `schema.sql`
- **SSL:** "Ignore SSL Issues" enabled on the connection
