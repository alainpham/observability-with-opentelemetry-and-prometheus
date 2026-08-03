#!/bin/bash

helm repo add grafana https://grafana.github.io/helm-charts &&
  helm repo update &&
  helm upgrade --install --atomic --timeout 300s grafana-k8s-monitoring grafana/k8s-monitoring \
    --version "^4" --namespace "${ALLOY_NAMESPACE}" --create-namespace --values - <<EOF
cluster:
  name: ${KUBE_CLUSTER_NAME}
destinations:
  grafana-cloud-metrics:
    type: prometheus
    url: "${PROM_URL}${PROM_REMOTEWRITE_PATH}"
    auth:
      type: basic
      username: "${PROM_USER}"
      password: $PROM_PASSWORD
  grafana-cloud-logs:
    type: loki
    url: ${LOKI_URL}/loki/api/v1/push
    auth:
      type: basic
      username: "${LOKI_USER}"
      password: $LOKI_PASSWORD
  gc-otlp-endpoint:
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
  grafana-cloud-profiles:
    type: pyroscope
    url: ${PROFILES_URL}
    auth:
      type: basic
      username: "${PROFILES_USER}"
      password: $PROFILES_PASSWORD
clusterMetrics:
  enabled: true
  collector: alloy-metrics
hostMetrics:
  enabled: true
  collector: alloy-metrics
  linuxHosts:
    enabled: true
  windowsHosts:
    enabled: true
  energyMetrics:
    enabled: true
costMetrics:
  enabled: true
  collector: alloy-metrics
annotationAutodiscovery:
  enabled: true
  collector: alloy-metrics
prometheusOperatorObjects:
  enabled: true
  collector: alloy-metrics
clusterEvents:
  enabled: true
  collector: alloy-singleton
nodeLogs:
  enabled: true
  collector: alloy-logs
podLogsViaLoki:
  enabled: true
  collector: alloy-logs
kubernetesManifests:
  enabled: true
  collector: alloy-singleton
applicationObservability:
  enabled: true
  collector: alloy-receiver
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
autoInstrumentation:
  enabled: false
  collector: alloy-metrics
  beyla:
    deliverTracesToApplicationObservability: false
profiling:
  enabled: true
  collector: alloy-profiles
  ebpf:
    enabled: true
    namespaces: [ ${APP_NAMESPACES} ]
  java:
    enabled: true
    namespaces: [ ${APP_NAMESPACES} ]
collectors:
  alloy-metrics:
    presets:
      - clustered
      - statefulset
  alloy-singleton:
    presets:
      - singleton
  alloy-logs:
    presets:
      - filesystem-log-reader
      - daemonset
  alloy-receiver:
    presets:
      - deployment
  alloy-profiles:
    presets:
      - privileged
      - daemonset
collectorCommon:
  alloy:
    remoteConfig:
      enabled: ${FLEET_ENABLED:-false}
      url: ${FLEET_URL}
      auth:
        type: basic
        username: "${FLEET_USER}"
        password: $FLEET_PASSWORD
telemetryServices:
  kube-state-metrics:
    deploy: true
  node-exporter:
    deploy: true
  windows-exporter:
    deploy: true
  opencost:
    deploy: true
    metricsSource: grafana-cloud-metrics
    opencost:
      exporter:
        defaultClusterId: ${KUBE_CLUSTER_NAME}
      prometheus:
        existingSecretName: grafana-cloud-metrics-grafana-k8s-monitoring
        external:
          url: "${PROM_URL}${PROM_PATH_FOR_OPENCOST}"
  kepler:
    deploy: true
  k8s-manifest-tail:
    deploy: true
    config:
      objects:
        - apiVersion: v1
          kind: Pod
        - apiVersion: apps/v1
          kind: Deployment
        - apiVersion: apps/v1
          kind: StatefulSet
        - apiVersion: apps/v1
          kind: DaemonSet
EOF
