# System: messenger

## Architecture

Synapse Matrix homeserver + Element X web client + LiveKit SFU + TURN server. Docker.

- Matrix: federation enabled, PostgreSQL backend
- A/V: LiveKit SFU with built-in TURN
- Deployment: blue/green via nginx-microservice

## Integrations

| Dependency | Usage |
|-----------|-------|
| database-server | PostgreSQL for Synapse |
| nginx-microservice | Reverse proxy + SSL |

## Current State
<!-- AI-maintained -->
Stage: production

## Known Issues
<!-- AI-maintained -->
- None
