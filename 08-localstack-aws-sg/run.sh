#!/usr/bin/env bash
# Pattern 08: AWS Security Group as code via LocalStack + OpenTofu.

set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
ng()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

say "1/5 LocalStack up"
docker compose up -d
echo "  waiting for /_localstack/health..."
for _ in $(seq 1 30); do
  if curl -fsS http://localhost:4566/_localstack/health >/dev/null 2>&1; then break; fi
  sleep 2
done
curl -s http://localhost:4566/_localstack/health | head -c 200; echo

say "2/5 OpenTofu init"
(cd terraform && tofu init -input=false -no-color | tail -5)

say "3/5 OpenTofu apply"
(cd terraform && tofu apply -input=false -auto-approve -no-color | tail -20)

say "4/5 Pulling SG state via aws cli"
AWS_ENDPOINT="http://localhost:4566"
AWS_ARGS=(--endpoint-url "$AWS_ENDPOINT" --region us-east-1)
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test

WEB_SG=$(cd terraform && tofu output -raw web_sg_id)
APP_SG=$(cd terraform && tofu output -raw app_sg_id)
DB_SG=$(cd terraform && tofu output -raw db_sg_id)
echo "  web_sg=$WEB_SG  app_sg=$APP_SG  db_sg=$DB_SG"

inspect() {
  local sgid=$1
  aws "${AWS_ARGS[@]}" ec2 describe-security-groups --group-ids "$sgid" \
    --query 'SecurityGroups[0].IpPermissions[].{from:FromPort,proto:IpProtocol,cidr:IpRanges[].CidrIp,srcSG:UserIdGroupPairs[].GroupId}' \
    --output json
}

WEB_JSON=$(inspect "$WEB_SG")
APP_JSON=$(inspect "$APP_SG")
DB_JSON=$(inspect "$DB_SG")
echo "--- web-sg ingress ---"; echo "$WEB_JSON" | jq .
echo "--- app-sg ingress ---"; echo "$APP_JSON" | jq .
echo "--- db-sg  ingress ---"; echo "$DB_JSON"  | jq .

say "5/5 Assertions"
echo "$WEB_JSON" | jq -e '.[] | select(.from==80) | .cidr | index("0.0.0.0/0")' >/dev/null \
  && ok "web-sg ingress 80 from 0.0.0.0/0" || ng "web-sg missing :80 from 0.0.0.0/0"

echo "$APP_JSON" | jq -e --arg sg "$WEB_SG" '.[] | select(.from==8080) | .srcSG | index($sg)' >/dev/null \
  && ok "app-sg ingress 8080 only from web-sg" || ng "app-sg missing :8080 from web-sg"

echo "$DB_JSON" | jq -e --arg sg "$APP_SG" '.[] | select(.from==5432) | .srcSG | index($sg)' >/dev/null \
  && ok "db-sg  ingress 5432 only from app-sg" || ng "db-sg missing :5432 from app-sg"

printf '\n\033[1;32mDone.\033[0m  Tear down with: ./cleanup.sh\n'
