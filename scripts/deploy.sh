#!/usr/bin/env bash
#
# One-command deploy: load .env, verify prerequisites, terraform init+apply,
# print the Grafana URL and admin password retrieval command.

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

for cmd in terraform aws docker; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${cmd}" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not reachable. Start Docker Desktop and retry." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required for multi-platform image builds." >&2
  exit 1
fi

caller_account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
if [[ -z "${caller_account}" ]]; then
  echo "AWS credentials are not configured. Run 'aws configure' or set AWS_PROFILE." >&2
  exit 1
fi

if [[ "${caller_account}" != "${TF_VAR_aws_account_id}" ]]; then
  echo "AWS caller account (${caller_account}) does not match TF_VAR_aws_account_id (${TF_VAR_aws_account_id})." >&2
  exit 1
fi

terraform init -input=false
terraform apply -auto-approve -input=false

grafana_url="$(terraform output -raw grafana_url 2>/dev/null || echo "")"
secret_name="$(terraform output -raw grafana_admin_secret_name 2>/dev/null || echo "")"
region="${TF_VAR_aws_region:-us-east-1}"

echo
echo "Deploy complete."
echo
if [[ -n "${grafana_url}" ]]; then
  echo "Grafana:        ${grafana_url}"
  echo "Login user:     admin"
  echo "Get password:   aws secretsmanager get-secret-value --region ${region} --secret-id '${secret_name}' --query SecretString --output text"
fi
