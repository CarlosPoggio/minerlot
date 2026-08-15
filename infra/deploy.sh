#!/usr/bin/env bash
# Renders config templates from infra/.env and (re)builds/starts the stack.
# Run this from the infra/ directory on the production server after a
# `git pull` (or on first-time setup, after creating .env from env.example).
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Missing infra/.env — copy env.example to .env and fill in real values first." >&2
  exit 1
fi

set -a
source .env
set +a

for var in RPC_USER RPC_PASSWORD WALLET_ADDRESS; do
  if [ -z "${!var:-}" ]; then
    echo "Missing required variable '$var' in .env" >&2
    exit 1
  fi
done

# IMPORTANT: envsubst substitutes every "${VARNAME}"-looking token in the
# file, not just the ones we intend — and index.html.template is full of
# unrelated JavaScript template-literal syntax that happens to look
# identical (${onlineActiveCount}, ${blocksForAddress}, etc.). Without an
# explicit restriction list, envsubst silently blanks every one of those
# to an empty string (since they're not real env vars), which is exactly
# what happened the first time this shipped: several dashboard tiles
# rendered blank with no error anywhere. Always pass the exact variable
# list so only real placeholders get touched.
envsubst '${RPC_USER} ${RPC_PASSWORD}' < bitcoin/bitcoin.conf.template > bitcoin/bitcoin.conf
envsubst '${RPC_USER} ${RPC_PASSWORD}' < public-pool.env.template > public-pool/.env
envsubst '${WALLET_ADDRESS}' < monitor/index.html.template > monitor/index.html

docker compose up -d --build --remove-orphans

echo "Deployed. Check status with: docker compose ps"
