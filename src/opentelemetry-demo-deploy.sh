#!/bin/bash

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

kubectl create namespace otel-demo --dry-run=client -o yaml | kubectl apply -f -

sed \
  -e "s/__ALLOY_NAMESPACE__/${ALLOY_NAMESPACE}/g" \
  <<'EOF' | helm upgrade --install otel-demo open-telemetry/opentelemetry-demo \
  --namespace "otel-demo" \
  --values -
default:
  env:
    - name: OTEL_SERVICE_NAME
      valueFrom:
        fieldRef:
          fieldPath: "metadata.labels['app.kubernetes.io/component']"
    - name: OTEL_COLLECTOR_NAME
      value: grafana-k8s-monitoring-alloy-receiver.__ALLOY_NAMESPACE__.svc.cluster.local
    - name: OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE
      value: cumulative
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: OTEL_RESOURCE_ATTRIBUTES
      value: "service.namespace=$(POD_NAMESPACE),service.instance.id=$(POD_NAMESPACE).$(POD_NAME).$(OTEL_SERVICE_NAME)"
opentelemetry-collector:
  enabled: false
jaeger:
  enabled: false
prometheus:
  enabled: false
grafana:
  enabled: false
opensearch:
  enabled: false
EOF