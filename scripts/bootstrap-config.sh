#!/usr/bin/env bash
#
# Seed (or update) the Secrets Manager secret that holds deploy-time config.
#
# Reads TF_VAR_aws_account_id, TF_VAR_alarm_email, TF_VAR_owner, TF_VAR_cost_center
# from the current environment (after sourcing .env) and writes them into
# ${OBS_CONFIG_SECRET_NAME} as a single JSON blob.
#
# Cost note: one Secrets Manager secret = $0.40/month. Bundling all values into
# one secret is intentional — adding more secrets multiplies the bill.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if [[ ! -f .env ]]; then
  echo "Missing .env. Copy .env.example to .env and fill in your values." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${TF_VAR_aws_profile:?TF_VAR_aws_profile is required in .env}"
: "${TF_VAR_aws_account_id:?TF_VAR_aws_account_id must be set in the environment for the initial bootstrap}"
: "${TF_VAR_alarm_email:?TF_VAR_alarm_email must be set in the environment for the initial bootstrap}"
: "${TF_VAR_owner:?TF_VAR_owner must be set in the environment for the initial bootstrap}"
: "${TF_VAR_cost_center:?TF_VAR_cost_center must be set in the environment for the initial bootstrap}"

export AWS_PROFILE="${TF_VAR_aws_profile}"
region="${TF_VAR_aws_region:-us-east-1}"
secret_name="${OBS_CONFIG_SECRET_NAME:-obs-platform/deploy-config}"

for cmd in aws jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${cmd}" >&2
    exit 1
  fi
done

caller_account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
if [[ "${caller_account}" != "${TF_VAR_aws_account_id}" ]]; then
  echo "AWS caller account (${caller_account}) does not match TF_VAR_aws_account_id (${TF_VAR_aws_account_id})." >&2
  exit 1
fi

secret_json="$(jq -n \
  --arg account_id "${TF_VAR_aws_account_id}" \
  --arg alarm_email "${TF_VAR_alarm_email}" \
  --arg owner "${TF_VAR_owner}" \
  --arg cost_center "${TF_VAR_cost_center}" \
  '{aws_account_id: $account_id, alarm_email: $alarm_email, owner: $owner, cost_center: $cost_center}')"

if aws secretsmanager describe-secret --region "${region}" --secret-id "${secret_name}" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --region "${region}" \
    --secret-id "${secret_name}" \
    --secret-string "${secret_json}" >/dev/null
  echo "Updated ${secret_name} in ${region}."
else
  aws secretsmanager create-secret \
    --region "${region}" \
    --name "${secret_name}" \
    --description "Deploy-time configuration for the AWS Enterprise Observability Platform." \
    --secret-string "${secret_json}" >/dev/null
  echo "Created ${secret_name} in ${region}."
fi

cat <<EOF

Trim .env to the minimum:

  export TF_VAR_aws_profile="${TF_VAR_aws_profile}"
  export OBS_CONFIG_SECRET_NAME="${secret_name}"

scripts/deploy.sh and scripts/destroy.sh will fetch the rest from Secrets Manager.
EOF
