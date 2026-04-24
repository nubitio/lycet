#!/usr/bin/env bash
set -euo pipefail

# Required:
#   PORTAINER_URL
#   PORTAINER_TOKEN (x-api-key)
#   STACK_ID or STACK_NAME
#   ENDPOINT_ID (fallback if stack doesn't provide EndpointId)
#   COMPOSE_FILE

PORTAINER_URL="${PORTAINER_URL:-}"
PORTAINER_TOKEN="${PORTAINER_TOKEN:-}"
STACK_ID="${STACK_ID:-}"
STACK_NAME="${STACK_NAME:-}"
ENDPOINT_ID="${ENDPOINT_ID:-}"
COMPOSE_FILE="${COMPOSE_FILE:-compose.yaml}"
SWARM_ID="${SWARM_ID:-}"

if [[ -z "$PORTAINER_URL" || -z "$PORTAINER_TOKEN" ]]; then
  echo "Missing PORTAINER_URL or PORTAINER_TOKEN" >&2
  exit 1
fi
if [[ -z "$STACK_ID" && -z "$STACK_NAME" ]]; then
  echo "Set STACK_ID or STACK_NAME" >&2
  exit 1
fi
if [[ -z "$ENDPOINT_ID" ]]; then
  echo "Missing ENDPOINT_ID" >&2
  exit 1
fi
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

STACKS_JSON=$(curl -sS -H "x-api-key: $PORTAINER_TOKEN" \
  "${PORTAINER_URL%/}/api/stacks")

if [[ -n "$STACK_ID" ]]; then
  STACK_JSON=$(printf "%s" "$STACKS_JSON" | jq -c ".[] | select(.Id == ($STACK_ID|tonumber))")
else
  STACK_JSON=$(printf "%s" "$STACKS_JSON" | jq -c ".[] | select(.Name == \"$STACK_NAME\")")
fi

if [[ -z "$STACK_JSON" ]]; then
  echo "Stack not found" >&2
  exit 1
fi

FOUND_ID=$(printf "%s" "$STACK_JSON" | jq -r '.Id')
FOUND_ENDPOINT=$(printf "%s" "$STACK_JSON" | jq -r '.EndpointId // empty')
FOUND_ENV=$(printf "%s" "$STACK_JSON" | jq -c '.Env // []')
FOUND_NAME=$(printf "%s" "$STACK_JSON" | jq -r '.Name')

ENDPOINT_TO_USE=${FOUND_ENDPOINT:-$ENDPOINT_ID}

PAYLOAD_FILE="/tmp/portainer_payload.json"
STACK_FILE_TMP="/tmp/portainer_stack.yml"
cp "$COMPOSE_FILE" "$STACK_FILE_TMP"

jq -Rs \
  --argjson env "$FOUND_ENV" \
  --arg name "$FOUND_NAME" \
  --arg swarm "$SWARM_ID" \
  '{
    env: $env,
    stackFileContent: .,
    prune: true,
    pullImage: true,
    name: $name
  } | if ($swarm | length) > 0 then . + {swarmID: $swarm} else . end' \
  "$STACK_FILE_TMP" > "$PAYLOAD_FILE"

curl --http1.1 -sS -X PUT \
  -H "x-api-key: $PORTAINER_TOKEN" \
  -H "Content-Type: application/json" \
  "${PORTAINER_URL%/}/api/stacks/${FOUND_ID}?endpointId=${ENDPOINT_TO_USE}" \
  --data-binary "@$PAYLOAD_FILE" >/dev/null

echo "Stack ${FOUND_NAME} deployed successfully"
