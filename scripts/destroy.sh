#!/usr/bin/env bash
#
# One-command teardown: load .env, verify the AWS caller matches TF_VAR_aws_account_id,
# and run terraform destroy. ECR repositories require ecr_force_delete=true to remove
# images on destroy — set TF_VAR_ecr_force_delete=true in .env first if you need that.

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

: "${TF_VAR_aws_account_id:?TF_VAR_aws_account_id is required in .env}"

# Make the named profile (if any) the active one for both Terraform and ad-hoc aws CLI calls below.
if [[ -n "${TF_VAR_aws_profile:-}" ]]; then
  export AWS_PROFILE="${TF_VAR_aws_profile}"
fi

for cmd in terraform aws; do
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

terraform destroy -auto-approve -input=false
