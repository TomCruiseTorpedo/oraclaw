# Models — which LLM runs what, and how to swap

This page explains the three "roles" a model can play in your OpenClaw setup, why every slug in this kit starts with `openrouter/`, and how to change any of them without breaking things.

> **Authoritative source for current free models on OpenRouter:**
> - Curated catalogue (browser-friendly): https://openrouter.ai/collections/free-models
> - Programmatic API: `https://openrouter.ai/api/v1/models` — filter `pricing.prompt == "0"`
>
> Slugs come and go. Bookmark the catalogue page so you can check it any time you suspect a model has gone away.

---

## The three roles

Every agent job runs through one of three model slots:

- **Primary** — the model your agent uses for real work: chat replies, tool calls, reasoning. This is the one you care about most. In this kit: `openrouter/nvidia/nemotron-3-super-120b-a12b:free`.
- **Fallbacks** — an ordered list tried in sequence if the primary fails (timeout, rate limit, model taken down, upstream auth error). The first one that answers wins. In this kit, the chain is: gemma → minimax → glm → qwen.
- **Heartbeat** — the model that runs the background cron heartbeat jobs (status checks every 5–60 minutes depending on time of day). These should be cheap and fast — they're not doing deep reasoning, just checking in. In this kit: `openrouter/z-ai/glm-4.5-air:free` (35B parameters — mid-sized, tool-use reliable; chosen for the heartbeat lane after the smaller Llama 3.2 3B Instruct started showing transient free-tier exhaustion).

Configuration lives in `~/.openclaw/openclaw.json` under `agents.defaults`:

- `agents.defaults.model.primary` — single slug (the Primary).
- `agents.defaults.model.fallbacks` — ordered array of slugs.
- `agents.defaults.heartbeat.model` — single slug (the Heartbeat).
- `agents.defaults.models` — a registry object: every slug that appears anywhere in the first three settings must also be listed here as a key. This is the gateway's allowlist.

The heartbeat model does **not** cascade from the primary. If `agents.defaults.heartbeat.model` fails, the lane falls through to the main fallbacks chain — but its "first try" is whatever you set explicitly for heartbeat. So choose the heartbeat model deliberately.

---

## Why every slug starts with `openrouter/`

OpenClaw routes a model slug by splitting on the first `/`. Everything before the slash is the provider name; everything after is the model ID at that provider. `google/gemma-4-31b-it:free` gets routed to the `google` provider plugin (direct Google AI Studio) — which needs a Google API key, separate from your OpenRouter key. `openrouter/google/gemma-4-31b-it:free` gets routed to the `openrouter` provider plugin, which uses your OpenRouter key and serves the same model.

If you see errors like `No API key found for provider "google"` or `Unknown model: zai/glm-4.5-air:free` in your logs, that's almost always a missing `openrouter/` prefix. Add it.

Rule of thumb: if you're using the free OpenRouter catalogue, **always prefix with `openrouter/`**. You only skip the prefix when you have a direct plan with the underlying provider (Anthropic, OpenAI, Google AI Studio, etc.) and have added its API key to OpenClaw separately.

---

## Prerequisites to change a model

- SSH access to your VM.
- A text editor you're comfortable with (`nano`, `vim`, `micro`).
- A restart of the gateway after editing — OpenClaw re-reads `openclaw.json` on service restart, not live.

---

## How to swap the primary model

1. Pick a new slug. Browse `https://openrouter.ai/collections/free-models` for free options. Confirm the model supports tool use (OpenClaw needs it) — most do; the model page says so.

2. SSH in and open the config: `ssh my-oraclaw 'nano ~/.openclaw/openclaw.json'`.

3. Make two edits:
   - Change `agents.defaults.model.primary` to the new slug (with `openrouter/` prefix).
   - Add the new slug as a key in `agents.defaults.models` if it isn't already.

4. Save, then restart: `ssh my-oraclaw 'systemctl --user restart openclaw-gateway'`.

5. Watch the first response come through. If it errors with `Unknown model`, check you got the slug exactly right (OpenRouter's slugs are case-sensitive and the `:free` suffix matters).

---

## How to swap the heartbeat model

Same pattern, different keys. Edit `agents.defaults.heartbeat.model` and make sure the new slug appears in `agents.defaults.models`. Restart.

Good heartbeat candidates share these traits: free on OpenRouter, tool-use capable, low-latency, and small *enough* to keep cost modest given the 10–100× heartbeat-vs-user-work cadence ratio. At time of writing, these work well: `openrouter/z-ai/glm-4.5-air:free` (35B — the current default; chosen for tool-use reliability after smaller models started showing transient free-tier exhaustion), `openrouter/google/gemma-2-9b-it:free`, `openrouter/qwen/qwen-2.5-7b-instruct:free`. Verify each one is still on the free collection (https://openrouter.ai/collections/free-models) before switching.

You don't *have* to set a different heartbeat model from your primary — it's fine for both slots to point at the same slug. You just give up the cost optimization.

---

## How to reorder the fallbacks chain

Edit `agents.defaults.model.fallbacks` (a JSON array). Order matters — the first entry is tried first. Put your favourite fallback at the top and the least-trusted at the bottom. Save and restart.

Adding a new fallback: drop its slug into the array *and* into `agents.defaults.models`. The registry requirement catches typos — the gateway will complain loudly if you reference a slug that isn't registered.

---

## Examples

**Example 1 — swap primary to nemotron, keep everything else:**

Before: `"primary": "openrouter/nvidia/nemotron-3-super-120b-a12b:free"`
After: `"primary": "openrouter/nvidia/nemotron-3-super-120b-a12b:free"`

Nemotron is already in `agents.defaults.models` (it's a fallback), so no registry edit needed. Just save and restart.

**Example 2 — add a paid Anthropic model as a top fallback:**

Before: `fallbacks` starts with gemma. After: add `"anthropic/claude-sonnet-4-6"` as the first entry, and add it as a key in `agents.defaults.models`. You'll also need `auth.profiles.anthropic:default` with an Anthropic API key — OpenClaw's doctor command walks you through this: `ssh my-oraclaw 'openclaw doctor'`.

**Example 3 — swap heartbeat to gemma 9B:**

Before: `"heartbeat": { ..., "model": "openrouter/meta-llama/llama-3.2-3b-instruct:free" }`
After: `"heartbeat": { ..., "model": "openrouter/google/gemma-2-9b-it:free" }`

Add `openrouter/google/gemma-2-9b-it:free` as a key in `agents.defaults.models`. Save, restart. Next heartbeat fires with the new model.

---

## Troubleshooting

**"All my heartbeats are failing with 404"** — The heartbeat model was deprecated or renamed upstream. Check the journal (`ssh my-oraclaw 'journalctl --user -u openclaw-gateway --since "1 hour ago" | grep -i "heartbeat\|model_not_found"'`), pick a replacement, swap as above.

**"Unknown model: <slug>"** — The slug isn't listed in `agents.defaults.models`. Add it as a key and restart. (Or the slug has a typo, or the `openrouter/` prefix is missing.)

**"No API key found for provider X"** — You're routing through a native provider plugin (e.g. `google/...` hits the Google plugin, which needs a Google key). Re-prefix the slug with `openrouter/` and it'll route through your OpenRouter key instead.

**"Model available on OpenRouter but OpenClaw rejects it"** — OpenClaw's internal model catalogue (under `~/.openclaw/agents/main/agent/models.json`) may not list the slug. Three options: (a) use a slug that IS in the catalogue, (b) add the slug to the catalogue by hand (see `FIELD-MANUAL.md` appendix), (c) wait for an OpenClaw update that expands the stock catalogue.

**"Heartbeats are using the primary model, not my heartbeat override"** — Confirm you edited `agents.defaults.heartbeat.model`, not `agents.defaults.model.primary`. Restart the gateway. Then watch the next heartbeat run: `ssh my-oraclaw 'journalctl --user -u openclaw-gateway -f | grep "agent:main:main:heartbeat"'` — the `model=` field on the run-start line tells you which one fired.

---

## Best practices

- **Pin specific slugs, not aliases.** `openrouter/free` is an alias that picks "whatever's free right now" and can silently swap models under you. Specific slugs (like `openrouter/nvidia/nemotron-3-super-120b-a12b:free`) are stable and auditable.

- **Keep the fallback chain diverse.** If all your fallbacks are from the same provider family (e.g. all Gemma variants), an outage there takes down your whole chain. Spread across providers: Google, Meta, Alibaba, NVIDIA, etc.

- **Review quarterly.** OpenRouter adds and retires free models regularly. Every 90 days, open the free-models collection page and confirm your chain still resolves. A 5-minute audit catches problems before they surface as silent failures.

- **Treat heartbeat model as cost policy.** Heartbeats fire 10–100x more often than user-initiated work. A 3B free model vs. a 70B paid model is a ~100x cost difference. Match the model to the job.

---

## Next steps

- Test a model swap on a non-critical VM first if you have one.
- Set up `scripts/verify-self-heal.sh` as a post-change smoke test — it confirms the gateway recovers from a forced restart after your config change.
- Read `docs/RECOVERY.md` if you ever see `502` after restarting the gateway.
