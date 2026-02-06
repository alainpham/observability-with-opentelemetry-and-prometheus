#!/bin/bash

export OTEL_OPERATOR_CERT_MANAGER_ENABLED="false"
export OTLP_BASIC_AUTH_HEADER="Basic  $(echo ${OTLP_USER}:${OTLP_PASSWORD} | base64 -w 0)"

kubectl create namespace opentelemetry-operator-system

kubectl create secret generic otlpbackend-auth \
  --namespace opentelemetry-operator-system \
  --from-literal=OTLP_USER="$OTLP_USER" \
  --from-literal=OTLP_URL="$OTLP_URL" \
  --from-literal=OTLP_PASSWORD="$OTLP_PASSWORD" \
  --from-literal=OTLP_BASIC_AUTH_HEADER="$OTLP_BASIC_AUTH_HEADER"

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade opentelemetry-stack \
  open-telemetry/opentelemetry-kube-stack \
  --install \
  --namespace opentelemetry-operator-system \
  --set opentelemetry-operator.admissionWebhooks.certManager.enabled=$OTEL_OPERATOR_CERT_MANAGER_ENABLED \
  --set-string clusterName="$KUBE_CLUSTER_NAME" \
  --set-string 'instrumentation.resource.resourceAttributes.deployment\.environment\.name'="$DEPLOYMENT_ENVIRONMENT_NAME" \
  -f https://raw.githubusercontent.com/alainpham/observability-with-opentelemetry-and-prometheus/refs/heads/master/src/opentelemetry-kube-stack-values.yml