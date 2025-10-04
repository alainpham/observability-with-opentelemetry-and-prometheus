#!/bin/bash

if [ -z "${ALLOY_NAMESPACE}" ]; then
  ALLOY_NAMESPACE="default"
fi

if [ -z "${KUBE_CLUSTER_NAME}" ]; then
  KUBE_CLUSTER_NAME="$WILDCARD_DOMAIN"
fi

if [ -z "${KUBE_CLUSTER_NAME}" ]; then
  KUBE_CLUSTER_NAME="sandbox"
fi

if [ -z "${PROM_REMOTEWRITE_PATH}" ]; then
  PROM_REMOTEWRITE_PATH="/api/prom/push"
fi

if [ "${PROM_REMOTEWRITE_PATH}" = "/api/prom/push" ]; then
  PROM_QUERY_PATH="/api/prom"
fi

helm repo add grafana https://grafana.github.io/helm-charts &&
  helm repo update &&
  helm upgrade --install --atomic --timeout 300s grafana-k8s-monitoring grafana/k8s-monitoring \
    --namespace "${ALLOY_NAMESPACE}" --create-namespace --values - <<EOF
cluster:
  name: ${KUBE_CLUSTER_NAME}
destinations:
  - name: grafana-cloud-metrics
    type: prometheus
    url: ${PROM_URL}${PROM_REMOTEWRITE_PATH}
    auth:
      type: basic
      username: "${PROM_USER}"
      password: $PROM_PASSWORD
  - name: grafana-cloud-logs
    type: loki
    url: ${LOKI_URL}/loki/api/v1/push
    auth:
      type: basic
      username: "${LOKI_USER}"
      password: $LOKI_PASSWORD
  - name: grafana-cloud-otlp-endpoint
    type: otlp
    url: ${OTLP_URL}
    protocol: http
    auth:
      type: basic
      username: "${OTLP_USER}"
      password: $OTLP_PASSWORD
    metrics:
      enabled: true
    logs:
      enabled: true
    traces:
      enabled: true
  - name: grafana-cloud-profiles
    type: pyroscope
    url: ${PROFILES_URL}
    auth:
      type: basic
      username: "${PROFILES_USER}"
      password: $PROFILES_PASSWORD
clusterMetrics:
  enabled: true
  opencost:
    enabled: true
    metricsSource: grafana-cloud-metrics
    opencost:
      exporter:
        defaultClusterId: ${KUBE_CLUSTER_NAME}
      prometheus:
        existingSecretName: grafana-cloud-metrics-grafana-k8s-monitoring
        external:
          url: ${PROM_URL}${PROM_QUERY_PATH}
  kepler:
    enabled: true
annotationAutodiscovery:
  enabled: true
clusterEvents:
  enabled: true
nodeLogs:
  enabled: true
podLogs:
  enabled: true
applicationObservability:
  enabled: true
  receivers:
    otlp:
      grpc:
        enabled: true
        port: 4317
      http:
        enabled: true
        port: 4318
    zipkin:
      enabled: true
      port: 9411
  connectors:
    grafanaCloudMetrics:
      enabled: true
profiling:
  enabled: true
  ebpf:
    enabled: true
    namespaces: [ ${APP_NAMESPACES} ]
  java:
    enabled: true
    namespaces: [ ${APP_NAMESPACES} ]
  pprof:
    enabled: false
integrations:
  alloy:
    instances:
      - name: alloy
        labelSelectors:
          app.kubernetes.io/name:
            - alloy-metrics
            - alloy-singleton
            - alloy-logs
            - alloy-receiver
            - alloy-profiles
alloy-metrics:
  enabled: true
alloy-singleton:
  enabled: true
alloy-logs:
  enabled: true
alloy-receiver:
  enabled: true
  alloy:
    extraPorts:
      - name: otlp-grpc
        port: 4317
        targetPort: 4317
        protocol: TCP
      - name: otlp-http
        port: 4318
        targetPort: 4318
        protocol: TCP
      - name: zipkin
        port: 9411
        targetPort: 9411
        protocol: TCP
alloy-profiles:
  enabled: true
EOF