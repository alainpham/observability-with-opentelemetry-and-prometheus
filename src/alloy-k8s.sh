helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install grafana-k8s-monitoring \
  --version "^4" --namespace monitoring --create-namespace \
  grafana/k8s-monitoring \
  --values - <<EOF
# ---------------------------------------------------------------------------
# CLUSTER: name added as the "cluster" label on all telemetry
# ---------------------------------------------------------------------------
cluster:
  name: ${KUBE_CLUSTER_NAME}

# ---------------------------------------------------------------------------
# DESTINATIONS: where telemetry is sent (Grafana Cloud backends)
# Features send to every destination that accepts their signal type.
# ---------------------------------------------------------------------------
destinations:
  grafana-cloud-metrics:
    type: prometheus
    url: "${PROM_URL}${PROM_REMOTEWRITE_PATH}"
    auth:
      type: basic
      username: "${PROM_USER}"
      password: "${PROM_PASSWORD}"
  grafana-cloud-logs:
    type: loki
    url: "${LOKI_URL}/loki/api/v1/push"
    auth:
      type: basic
      username: "${LOKI_USER}"
      password: "${LOKI_PASSWORD}"
  gc-otlp-endpoint:
    type: otlp
    url: "${OTLP_URL}"
    protocol: http
    auth:
      type: basic
      username: "${OTLP_USER}"
      password: "${OTLP_PASSWORD}"
    metrics:
      enabled: true
    logs:
      enabled: true
    traces:
      enabled: true
  grafana-cloud-profiles:
    type: pyroscope
    url: "${PROFILES_URL}"
    auth:
      type: basic
      username: "${PROFILES_USER}"
      password: "${PROFILES_PASSWORD}"

# ---------------------------------------------------------------------------
# FEATURES: what to collect. Each one runs on the collector named in "collector:"
# ---------------------------------------------------------------------------

# Metrics
# cAdvisor, kubelet, kubelet resources, kube-state-metrics
clusterMetrics:
  enabled: true
  collector: alloy-daemonset
# node-exporter, kepler
hostMetrics:
  enabled: true
  collector: alloy-daemonset
  linuxHosts:
    enabled: true
    # extra node-exporter metrics on top of the default allow list
    metricsTuning:
      includeMetrics: [node_uname_info]
  energyMetrics:
    enabled: true
# opencost
costMetrics:
  enabled: true
  collector: alloy-daemonset
# pods and services annotated k8s.grafana.com/scrape=true
annotationAutodiscovery:
  enabled: true
  collector: alloy-daemonset
# PodMonitor, Probe, ServiceMonitor objects (requires the Prometheus Operator CRDs)
prometheusOperatorObjects:
  enabled: true
  collector: alloy-daemonset

# Logs
nodeLogs:
  enabled: true
  collector: alloy-daemonset
podLogsViaLoki:
  enabled: true
  collector: alloy-daemonset
# sharded across the clustered daemonset pods, so events are not duplicated
clusterEvents:
  enabled: true
  collector: alloy-daemonset
  clustering: true
# reads the k8s-manifest-tail logs (clustered)
kubernetesManifests:
  enabled: true
  collector: alloy-daemonset

# Traces, metrics and logs sent by applications over OTLP
applicationObservability:
  enabled: true
  collector: alloy-deployment
  receivers:
    otlp:
      grpc:
        enabled: true
        port: 4317
      http:
        enabled: true
        port: 4318

# Profiles
# Opt-in per pod with annotations on the pod template, in any namespace:
#   profiles.grafana.com/cpu.ebpf.enabled: "true"   -> eBPF CPU profiling
#   profiles.grafana.com/java.enabled: "true"       -> Java profiling
#   profiles.grafana.com/<type>.scrape: "true"      -> pprof scraping, <type> = cpu, memory, goroutine, block, mutex, fgprof
#   profiles.grafana.com/<type>.port: "<port>"      -> pprof port (optional .path, .scheme, .container)
# Set targetingScheme: all on ebpf / java to profile every pod instead (opt out with "false").
profiling:
  enabled: true
  collector: alloy-profiles
  # CPU profiles without code change: native (Go, Rust, C/C++), Java (Hotspot), .NET, Python, Ruby, PHP, Perl, Node.js (V8)
  ebpf:
    enabled: true
    # the Python unwinder exceeds the kernel 7.0 eBPF verifier limit (1M instructions) and
    # stops the whole eBPF profiler from loading; Python can still be profiled with the Pyroscope SDK
    pythonEnabled: false
  # CPU, allocation and lock profiles by attaching async-profiler to the JVM
  java:
    enabled: true
  # scrapes pprof HTTP endpoints, e.g. Go net/http/pprof or Pyroscope SDKs exposing pprof
  pprof:
    enabled: true

# Auto-instrumentation
# Beyla (eBPF) generates RED metrics and traces without code change.
# Opt-in per pod with this annotation on the pod template, in any namespace:
#   beyla.grafana.com/instrument: "true"
autoInstrumentation:
  enabled: true
  collector: alloy-daemonset
  beyla:
    # send Beyla traces to the applicationObservability OTLP receiver on alloy-deployment
    deliverTracesToApplicationObservability: true
    # traces only: RED / span / service graph metrics are generated from the traces in Grafana Cloud,
    # so Beyla exports no metric groups and only its own beyla_* health metrics are scraped
    metricsTuning:
      includeMetrics: ["beyla_.*"]
    config:
      data:
        discovery:
          instrument:
            - k8s_pod_annotations:
                beyla.grafana.com/instrument: "true"
        prometheus_export:
          features: []

# ---------------------------------------------------------------------------
# COLLECTORS: the Alloy instances that run the features above.
# Presets set the workload type (daemonset / deployment / singleton) and permissions.
# ---------------------------------------------------------------------------
collectors:
  alloy-daemonset:
    presets: [xlarge, root, host-network, host-storage, host-cgroup, clustered, service-discovery, filesystem-log-reader, daemonset]
    controller:
      autoscaling:
        vertical:
          enabled: true
          resourcePolicy:
            containerPolicies:
              - containerName: alloy
                controlledResources: [cpu, memory]
                controlledValues: RequestsAndLimits
                maxAllowed:
                  cpu: 4
                  memory: 8Gi
                minAllowed:
                  cpu: 1
                  memory: 2Gi

  alloy-deployment:
    presets: [xlarge, clustered, deployment]
    extraService:
      enabled: true
      name: otel-receiver
    # Faro receiver for browser (frontend) telemetry, the chart has no Faro feature so it is raw Alloy config.
    # Faro logs go to Loki, Faro traces go through the OTLP destination pipeline.
    includeDestinations: [grafana-cloud-logs]
    alloy:
      extraPorts:
        - name: faro
          port: 12347
          targetPort: 12347
          protocol: TCP
    extraConfig: |
      faro.receiver "frontend" {
        server {
          listen_address       = "0.0.0.0"
          listen_port          = 12347
          cors_allowed_origins = ["*"]
        }
        output {
          logs   = [loki.write.grafana_cloud_logs.receiver]
          traces = [otelcol.processor.attributes.gc_otlp_endpoint.input]
        }
      }
    controller:
      autoscaling:
        horizontal:
          enabled: true
          minReplicas: 1
          maxReplicas: 5
          targetCPUUtilizationPercentage: 75
          targetMemoryUtilizationPercentage: 80

  # privileged daemonset dedicated to profiling, so the main daemonset stays unprivileged
  alloy-profiles:
    presets: [privileged, daemonset]

# ---------------------------------------------------------------------------
# TELEMETRY SERVICES: exporters and helpers deployed by the chart.
# They expose data; the features above scrape or read them.
# ---------------------------------------------------------------------------
telemetryServices:
  # host metrics (hostMetrics)
  node-exporter:
    deploy: true

  # Kubernetes object metrics (clusterMetrics)
  kube-state-metrics:
    deploy: true

  # Beyla k8s metadata cache: off, autoInstrumentation deploys its own
  beyla:
    deploy: false

  # cost metrics (costMetrics); reads back from Prometheus
  opencost:
    deploy: true
    metricsSource: custom
    opencost:
      exporter:
        defaultClusterId: "${KUBE_CLUSTER_NAME}"
      prometheus:
        username: "${PROM_USER}"
        password: "${PROM_PASSWORD}"
        external:
          url: "${PROM_URL}${PROM_PATH_FOR_OPENCOST}"

  # energy metrics (hostMetrics.energyMetrics)
  kepler:
    deploy: true

  # logs manifest changes (kubernetesManifests)
  k8s-manifest-tail:
    deploy: true
    config:
      objects:
        - { apiVersion: v1, kind: Pod }
        - { apiVersion: apps/v1, kind: Deployment }
        - { apiVersion: apps/v1, kind: StatefulSet }
        - { apiVersion: apps/v1, kind: DaemonSet }

  # injects instrumentation SDKs into application pods
  sdkInjector:
    deploy: true
    allowedConfigMapWriters: system:serviceaccount:monitoring:grafana-k8s-monitoring-alloy-daemonset,system:serviceaccount:monitoring:grafana-k8s-monitoring-alloy-deployment
EOF
