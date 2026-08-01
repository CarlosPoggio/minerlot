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

envsubst < bitcoin/bitcoin.conf.template > bitcoin/bitcoin.conf
envsubst < public-pool.env.template > public-pool/.env
envsubst < monitor/index.html.template > monitor/index.html

docker compose up -d --build

echo "Deployed. Check status with: docker compose ps"
