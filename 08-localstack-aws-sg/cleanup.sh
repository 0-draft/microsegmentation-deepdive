#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
echo "==> Destroying OpenTofu state"
(cd terraform && tofu destroy -input=false -auto-approve -no-color 2>/dev/null | tail -5) || true
echo "==> Stopping LocalStack"
docker compose down -v
echo "==> Removing .terraform"
rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate*
