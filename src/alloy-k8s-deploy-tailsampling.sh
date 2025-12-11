#!/bin/bash

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
  - name: gc-otlp-endpoint
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
    processors:
      serviceGraphMetrics:
        enabled: true
        destinations: 
          - grafana-cloud-metrics
        dimensions:
          - service.name
          - service.namespace
          - deployment.environment.name
          - k8s.cluster.name
      tailSampling:
        enabled: true
        policies:
          # Keep errors and unset status codes
          - name: "keep-errors"
            type: "status_code"
            status_codes: ["ERROR"]
          # Sample slow traces
          - name: "sample-slow-traces"
            type: "latency"
            threshold_ms: 1000
          - name: "standard-sampling"
            type: "probabilistic"
            sampling_percentage: 100
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
    enabled: false
    metricsSource: grafana-cloud-metrics
    opencost:
      exporter:
        defaultClusterId: ${KUBE_CLUSTER_NAME}
      prometheus:
        existingSecretName: grafana-cloud-metrics-grafana-k8s-monitoring
        external:
          url: ${PROM_URL}${PROM_PATH_FOR_OPENCOST}
  node-exporter:
    service:
      port: 9101
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
    spanMetrics:
      enabled: true
      exemplars:
        enabled: true
        max_per_data_point: 5
      dimensions:
        - name: service.name
        - name: deployment.environment.name
        - name: k8s.cluster.name
        - name: k8s.namespace.name
        - name: k8s.pod.name
      histogram:
        explicit:
          buckets: ["0.1s", "0.5s", "0.75s", "1s", "2s", "5s"]
        unit: "s"
      transforms:
        datapoint:
          - set(resource.attributes["service.instance.id"], attributes["k8s.pod.name"]) where attributes["k8s.pod.name"] != nil
          - set(resource.attributes["service.instance.id"], resource.attributes["k8s.pod.ip"]) where attributes["k8s.pod.name"] == nil
autoInstrumentation:
  enabled: false
  beyla:
    deliverTracesToApplicationObservability: false
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