# Tenant telemetry Helm values

Per-cloud Helm values files for the fluent-bit and opentelemetry-collector
upstream charts, wired to send tenant pod logs/metrics/traces into the
cloud-native observability backends provisioned by `astrolift-opscode`'s
observability modules (CloudWatch / Cloud Logging / Log Analytics + their
metric/trace counterparts).

## Layout

```
helm/tenant-telemetry/
  fluent-bit/
    values-aws.yaml       # CloudWatch Logs output (IRSA via observability-fluent-bit)
    values-gcp.yaml       # Cloud Logging output (Workload Identity via gcp module)
    values-azure.yaml     # Log Analytics output (WI Federation via azure module)
    values-kind.yaml      # Loki output (in-cluster, dev/kind)
  otel-collector/
    values-aws.yaml       # X-Ray + CloudWatch metrics
    values-gcp.yaml       # Cloud Trace + Cloud Monitoring + Cloud Logging
    values-azure.yaml     # Azure Monitor + Application Insights
    values-kind.yaml      # Tempo + Prometheus + Loki (in-cluster)
```

## Usage

After Terraform applies the relevant observability module (which provisions
the IRSA role / GSA / UAMI), pull the role/identity ID from the outputs and
install the chart with the matching values file:

```bash
# AWS
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n kube-system -f helm/tenant-telemetry/fluent-bit/values-aws.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$IRSA_ROLE_ARN"

# GCP
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n kube-system -f helm/tenant-telemetry/fluent-bit/values-gcp.yaml \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"="$GSA_EMAIL"

# Azure
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n kube-system -f helm/tenant-telemetry/fluent-bit/values-azure.yaml \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"="$UAMI_CLIENT_ID"

# kind / dev
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n kube-system -f helm/tenant-telemetry/fluent-bit/values-kind.yaml
```

Same pattern for `otel-collector` with the `open-telemetry/opentelemetry-collector` chart.

## Multi-tenant output routing

Tenant logs are tagged with `astrolift.dev/org=<org>` via a Kubernetes
filter at ingest time. Operators wanting per-org log destinations (e.g.
"org acme's logs go to a separate CloudWatch log group") customise the
output filters in their per-cluster overrides — the templates here ship
single-output defaults to keep the baseline simple.
