#!/bin/sh
set -eu

: "${AWS_REGION:?AWS_REGION must be set}"
: "${APP_LOG_GROUP:?APP_LOG_GROUP must be set}"
: "${CLUSTER_NAME:?CLUSTER_NAME must be set}"
: "${SERVICE_NAME:?SERVICE_NAME must be set}"
: "${ALB_ARN_SUFFIX:?ALB_ARN_SUFFIX must be set}"
: "${TARGET_GROUP_ARN_SUFFIX:?TARGET_GROUP_ARN_SUFFIX must be set}"

TEMPLATE_DIR="/opt/dashboard-templates"
RENDER_DIR="/var/lib/grafana/dashboards"

mkdir -p "${RENDER_DIR}"

for src in "${TEMPLATE_DIR}"/*.json; do
  dest="${RENDER_DIR}/$(basename "${src}")"
  sed \
    -e "s|__AWS_REGION__|${AWS_REGION}|g" \
    -e "s|__APP_LOG_GROUP__|${APP_LOG_GROUP}|g" \
    -e "s|__CLUSTER_NAME__|${CLUSTER_NAME}|g" \
    -e "s|__SERVICE_NAME__|${SERVICE_NAME}|g" \
    -e "s|__ALB_ARN_SUFFIX__|${ALB_ARN_SUFFIX}|g" \
    -e "s|__TARGET_GROUP_ARN_SUFFIX__|${TARGET_GROUP_ARN_SUFFIX}|g" \
    -e "s|__CLOUDWATCH_UID__|cloudwatch-observability|g" \
    -e "s|__XRAY_UID__|xray-observability|g" \
    "${src}" > "${dest}"
done

exec /run.sh "$@"
