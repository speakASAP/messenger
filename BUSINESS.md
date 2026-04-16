# Business: messenger
>
> ⚠️ IMMUTABLE BY AI.

## Goal

Self-hosted Matrix messaging with Synapse homeserver + LiveKit SFU for A/V calls. Internal team communication.

## Constraints

- AI must never access or read message content
- User data is private — no export without explicit approval
- LiveKit TURN credentials managed in .env only

## Consumers

Internal team only.

## SLA

- Production: <https://messenger.alfares.cz>
- Matrix federation enabled
