# CLAUDE.md (messenger)

Ecosystem defaults: sibling [`../CLAUDE.md`](../CLAUDE.md) and [`../shared/docs/PROJECT_AGENT_DOCS_STANDARD.md`](../shared/docs/PROJECT_AGENT_DOCS_STANDARD.md).

Read this repo's `BUSINESS.md` → `SYSTEM.md` → `AGENTS.md` → `TASKS.md` → `STATE.json` first.

---

## messenger

**Purpose**: Self-hosted Matrix messaging (Synapse) + Element X web client + LiveKit SFU for A/V calls. Internal team communication only.  
**Domain**: https://messenger.alfares.cz  
**Stack**: Synapse Matrix homeserver · Element X · LiveKit SFU · TURN server · PostgreSQL · Docker

### Key constraints
- Never access or read message content — privacy absolute
- Never export user data without explicit owner approval
- LiveKit TURN credentials in `.env` only — never log them
- Matrix federation is enabled — be careful with server config changes that affect federation

### Quick ops
```bash
docker compose logs -f
./scripts/deploy.sh
```
