FROM grafana/grafana:11.3.0

USER root

RUN grafana cli plugins install grafana-x-ray-datasource

COPY provisioning/datasources/datasources.yaml /etc/grafana/provisioning/datasources/datasources.yaml
COPY provisioning/dashboards/dashboards.yaml   /etc/grafana/provisioning/dashboards/dashboards.yaml
COPY dashboards.tmpl/                          /opt/dashboard-templates/
COPY entrypoint.sh                             /usr/local/bin/observability-entrypoint.sh

RUN mkdir -p /var/lib/grafana/dashboards \
 && chown -R grafana:root /var/lib/grafana /opt/dashboard-templates /etc/grafana/provisioning \
 && chmod +x /usr/local/bin/observability-entrypoint.sh

USER grafana

ENV GF_PATHS_PROVISIONING=/etc/grafana/provisioning \
    GF_AUTH_ANONYMOUS_ENABLED=false \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_INSTALL_PLUGINS=""

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/observability-entrypoint.sh"]
