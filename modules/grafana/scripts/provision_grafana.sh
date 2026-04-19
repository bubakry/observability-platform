#!/usr/bin/env bash

set -euo pipefail

required_env_vars=(
  GRAFANA_URL
  GRAFANA_API_KEY
  GRAFANA_FOLDER_UID
  GRAFANA_FOLDER_TITLE
  CLOUDWATCH_TEMPLATE_PATH
  XRAY_TEMPLATE_PATH
  DASHBOARDS_DIR
  AWS_REGION
  CLUSTER_NAME
  SERVICE_NAME
  APP_LOG_GROUP
  ALB_ARN_SUFFIX
  TARGET_GROUP_ARN_SUFFIX
)

for env_var in "${required_env_vars[@]}"; do
  if [[ -z "${!env_var:-}" ]]; then
    echo "Missing required environment variable: ${env_var}" >&2
    exit 1
  fi
done

grafana_api() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"

  if [[ -n "${payload}" ]]; then
    curl --silent --show-error --fail \
      --request "${method}" \
      --url "${GRAFANA_URL}${path}" \
      --header "Authorization: Bearer ${GRAFANA_API_KEY}" \
      --header "Content-Type: application/json" \
      --data "${payload}"
    return
  fi

  curl --silent --show-error --fail \
    --request "${method}" \
    --url "${GRAFANA_URL}${path}" \
    --header "Authorization: Bearer ${GRAFANA_API_KEY}" \
    --header "Content-Type: application/json"
}

render_template() {
  local template_path="$1"

  sed \
    -e "s|__AWS_REGION__|${AWS_REGION}|g" \
    -e "s|__APP_LOG_GROUP__|${APP_LOG_GROUP}|g" \
    -e "s|__CLUSTER_NAME__|${CLUSTER_NAME}|g" \
    -e "s|__SERVICE_NAME__|${SERVICE_NAME}|g" \
    -e "s|__ALB_ARN_SUFFIX__|${ALB_ARN_SUFFIX}|g" \
    -e "s|__TARGET_GROUP_ARN_SUFFIX__|${TARGET_GROUP_ARN_SUFFIX}|g" \
    -e "s|__CLOUDWATCH_UID__|cloudwatch-observability|g" \
    -e "s|__XRAY_UID__|xray-observability|g" \
    "${template_path}"
}

wait_for_grafana() {
  local attempts=0

  until curl --silent --show-error --fail \
    --header "Authorization: Bearer ${GRAFANA_API_KEY}" \
    "${GRAFANA_URL}/api/health" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "${attempts}" -gt 30 ]]; then
      echo "Timed out waiting for Amazon Managed Grafana to become reachable." >&2
      exit 1
    fi

    sleep 10
  done
}

ensure_folder() {
  if grafana_api "GET" "/api/folders/${GRAFANA_FOLDER_UID}" >/dev/null 2>&1; then
    return
  fi

  local payload
  payload="$(jq -n \
    --arg uid "${GRAFANA_FOLDER_UID}" \
    --arg title "${GRAFANA_FOLDER_TITLE}" \
    '{uid: $uid, title: $title}')"

  grafana_api "POST" "/api/folders" "${payload}" >/dev/null
}

upsert_datasource() {
  local template_path="$1"
  local uid="$2"
  local existing_id=""
  local payload=""

  payload="$(render_template "${template_path}")"

  if existing_json="$(grafana_api "GET" "/api/datasources/uid/${uid}" 2>/dev/null)"; then
    existing_id="$(jq -r '.id' <<<"${existing_json}")"
    grafana_api "DELETE" "/api/datasources/${existing_id}" >/dev/null
    sleep 1
  fi

  grafana_api "POST" "/api/datasources" "${payload}" >/dev/null
}

import_dashboard() {
  local dashboard_path="$1"
  local dashboard_json=""
  local payload=""

  dashboard_json="$(render_template "${dashboard_path}" | jq '.id = null')"
  payload="$(jq -n \
    --arg folder_uid "${GRAFANA_FOLDER_UID}" \
    --argjson dashboard "${dashboard_json}" \
    '{dashboard: $dashboard, folderUid: $folder_uid, overwrite: true}')"

  grafana_api "POST" "/api/dashboards/db" "${payload}" >/dev/null
}

wait_for_grafana
ensure_folder

upsert_datasource "${CLOUDWATCH_TEMPLATE_PATH}" "cloudwatch-observability"
upsert_datasource "${XRAY_TEMPLATE_PATH}" "xray-observability"

for dashboard_path in "${DASHBOARDS_DIR}"/*.json; do
  import_dashboard "${dashboard_path}"
done

echo "Grafana datasources and dashboards are provisioned."

