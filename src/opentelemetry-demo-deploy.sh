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
          fieldPath: "metadata.labels['app.kubernetes.io/name']"
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

components:
  accounting:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  ad:
    podAnnotations:
      profiles.grafana.com/java.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  cart:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  checkout:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  currency:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  email:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  fraud-detection:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  frontend:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  frontend-proxy:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "false"
      resource.opentelemetry.io/service.namespace: otel-demo
      io.opentelemetry.discovery.metrics/enabled: 'true'
      io.opentelemetry.discovery.metrics/scraper: httpcheck
      io.opentelemetry.discovery.metrics/config: |
          targets:
            - endpoint: "http://`endpoint`"
  image-provider:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "false"
      resource.opentelemetry.io/service.namespace: otel-demo
      io.opentelemetry.discovery.metrics/enabled: 'true'
      io.opentelemetry.discovery.metrics/scraper: nginx
      io.opentelemetry.discovery.metrics/config: |
          endpoint: "http://`endpoint`/status"
          collection_interval: "10s"
          timeout: "20s"
  load-generator:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  payment:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  product-catalog:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  product-reviews:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  quote:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  recommendation:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  shipping:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  flagd:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  kafka:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "false"
      resource.opentelemetry.io/service.namespace: otel-demo
  llm:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "true"
      resource.opentelemetry.io/service.namespace: otel-demo
  postgresql:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "false"
      resource.opentelemetry.io/service.namespace: otel-demo
      io.opentelemetry.discovery.metrics/enabled: 'true'
      io.opentelemetry.discovery.metrics/scraper: postgresql
      io.opentelemetry.discovery.metrics/config: |
        username: root
        password: otel
        metrics:
          postgresql.blks_hit:
            enabled: true
          postgresql.blks_read:
            enabled: true
          postgresql.tup_fetched:
            enabled: true
          postgresql.tup_returned:
            enabled: true
          postgresql.tup_inserted:
            enabled: true
          postgresql.tup_updated:
            enabled: true
          postgresql.tup_deleted:
            enabled: true
          postgresql.deadlocks:
            enabled: true
        tls:
          insecure: true
  valkey-cart:
    podAnnotations:
      profiles.grafana.com/cpu.ebpf.enabled: "false"
      resource.opentelemetry.io/service.namespace: otel-demo
      io.opentelemetry.discovery.metrics/enabled: 'true'
      io.opentelemetry.discovery.metrics/scraper: redis
      io.opentelemetry.discovery.metrics/config: |
        username: valkey
        collection_interval: 10s
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