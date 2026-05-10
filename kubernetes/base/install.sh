#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Astrolift — Kubernetes Base Platform Install (kind / dev convenience)
#
# Installs the foundational tools every cluster needs before application
# workloads can deploy. For production + customer-operator installs, prefer
# the umbrella chart at helm/astrolift-prereqs/ (chart for prod, this script
# for kind/dev).
#
# Each prereq below maps to a toggle in the umbrella chart's values.yaml so
# the two paths stay aligned. Use --skip <name> to turn off specific prereqs.
#
# Usage:
#   ./kubernetes/base/install.sh <kind|aws|gcp|azure> <env> [options]
#
# Options:
#   --cluster-name <name>    Cluster name (default: {env}-astrolift)
#   --alb-role-arn <arn>     ALB controller IRSA role ARN (aws only)
#   --skip <prereq>          Skip a prereq (repeatable). Names match values.yaml
#                            keys: certManager, externalSecrets, gatewayApi,
#                            envoyGateway, albController, externalDns, fluentBit,
#                            loki, prometheus, argocd
#   --dry-run                Show what would be installed
#
# Examples:
#   ./kubernetes/base/install.sh kind dev
#   ./kubernetes/base/install.sh aws dev --alb-role-arn arn:aws:iam::123:role/...
#   ./kubernetes/base/install.sh kind dev --skip argocd --skip loki
# -----------------------------------------------------------------------------

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLOUD="${1:?Usage: install.sh <kind|aws|gcp|azure> <env> [options]}"
ENV="${2:?Usage: install.sh <kind|aws|gcp|azure> <env> [options]}"
shift 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "${SCRIPT_DIR}")"
VALUES_DIR="${K8S_DIR}/values/${CLOUD}"

CLUSTER_NAME="${ENV}-astrolift"
ALB_ROLE_ARN=""
DRY_RUN=false
declare -A SKIP=()

# kind profile: skip cloud-specific prereqs by default. Operators on kind
# don't have ACM / Cloud DNS / cloud secret managers; the script defaults
# to the dev essentials only.
if [[ "${CLOUD}" == "kind" ]]; then
  SKIP[albController]=1
  SKIP[externalDns]=1
  SKIP[externalSecrets]=1
  # When running against kind, fall back to the aws values dir's neutral
  # subset (no cloud-specific annotations needed for the prereqs that do
  # install). Operators with custom kind values can pass their own dir.
  VALUES_DIR="${K8S_DIR}/values/aws"
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --alb-role-arn) ALB_ROLE_ARN="$2"; shift 2 ;;
    --skip) SKIP[$2]=1; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

skip() { [[ -n "${SKIP[$1]:-}" ]]; }

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------

command -v helm >/dev/null 2>&1 || error "helm is not installed"
command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
[[ -d "${VALUES_DIR}" ]] || error "Values directory not found: ${VALUES_DIR}"

info "Cloud: ${CLOUD}, Env: ${ENV}, Cluster: ${CLUSTER_NAME}"

if ${DRY_RUN}; then
  warn "DRY RUN — showing what would be installed"
fi

# -----------------------------------------------------------------------------
# Add Helm repos
# -----------------------------------------------------------------------------

info "Adding Helm repositories..."

helm_repo_add() {
  helm repo add "$1" "$2" 2>/dev/null || true
}

helm_repo_add jetstack https://charts.jetstack.io
helm_repo_add external-secrets https://charts.external-secrets.io
helm_repo_add external-dns https://kubernetes-sigs.github.io/external-dns
helm_repo_add grafana https://grafana.github.io/helm-charts
helm_repo_add prometheus-community https://prometheus-community.github.io/helm-charts
helm_repo_add fluent https://fluent.github.io/helm-charts
helm_repo_add argo https://argoproj.github.io/argo-helm

if [[ "${CLOUD}" == "aws" ]]; then
  helm_repo_add eks https://aws.github.io/eks-charts
fi

helm repo update >/dev/null 2>&1
success "Helm repos ready"

# -----------------------------------------------------------------------------
# Install helper
# -----------------------------------------------------------------------------

helm_install() {
  local name="$1"
  local chart="$2"
  local namespace="$3"
  local values_file="$4"
  shift 4
  local extra_args=("$@")

  info "Installing ${name}..."

  local cmd=(
    helm upgrade --install "${name}" "${chart}"
    --namespace "${namespace}" --create-namespace
    -f "${values_file}"
    "${extra_args[@]}"
  )

  if ${DRY_RUN}; then
    echo "  ${cmd[*]} --dry-run"
    helm upgrade --install "${name}" "${chart}" \
      --namespace "${namespace}" --create-namespace \
      -f "${values_file}" \
      "${extra_args[@]}" \
      --dry-run 2>&1 | tail -3
  else
    "${cmd[@]}" --wait --timeout 5m >/dev/null 2>&1 && success "  ${name} installed" || warn "  ${name} install had warnings"
  fi
}

# -----------------------------------------------------------------------------
# Install components
# -----------------------------------------------------------------------------

# 1. cert-manager
if ! skip certManager; then
  helm_install cert-manager jetstack/cert-manager cert-manager \
    "${VALUES_DIR}/cert-manager.yaml"
else
  info "Skipping cert-manager (--skip certManager)"
fi

# 2. external-secrets
if ! skip externalSecrets; then
  helm_install external-secrets external-secrets/external-secrets external-secrets \
    "${VALUES_DIR}/external-secrets.yaml"
else
  info "Skipping external-secrets (--skip externalSecrets)"
fi

# 3. Gateway API + Envoy Gateway
# Gateway API is the Kubernetes standard replacing Ingress.
# https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/
if ! skip gatewayApi; then
  info "Installing Gateway API CRDs..."
  if ! ${DRY_RUN}; then
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml 2>/dev/null \
      && success "  Gateway API CRDs installed" || warn "  Gateway API CRDs may already exist"
  fi
fi

if ! skip envoyGateway; then
  helm_install envoy-gateway oci://docker.io/envoyproxy/gateway-helm envoy-gateway-system \
    "${VALUES_DIR}/envoy-gateway.yaml"
else
  info "Skipping envoy-gateway (--skip envoyGateway)"
fi

# 4. ALB controller (aws only — manages AWS ALB via Gateway API or Ingress)
if [[ "${CLOUD}" == "aws" ]] && ! skip albController; then
  if [[ -z "${ALB_ROLE_ARN}" ]]; then
    warn "No --alb-role-arn provided. ALB controller will not have IAM permissions."
    warn "Get the ARN from: terraform output -raw alb_controller_role_arn"
  fi
  helm_install aws-load-balancer-controller eks/aws-load-balancer-controller kube-system \
    "${VALUES_DIR}/alb-controller.yaml" \
    --set "clusterName=${CLUSTER_NAME}" \
    --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ALB_ROLE_ARN}"
fi

# 5. external-dns
if ! skip externalDns; then
  helm_install external-dns external-dns/external-dns external-dns \
    "${VALUES_DIR}/external-dns.yaml"
else
  info "Skipping external-dns (--skip externalDns)"
fi

# 6. Fluent Bit (log collection → Loki)
if ! skip fluentBit; then
  helm_install fluent-bit fluent/fluent-bit logging \
    "${VALUES_DIR}/fluent-bit.yaml"
else
  info "Skipping fluent-bit (--skip fluentBit)"
fi

# 7. Loki (log aggregation backend)
if ! skip loki; then
  helm_install loki grafana/loki-stack loki \
    "${VALUES_DIR}/loki-stack.yaml"
else
  info "Skipping loki (--skip loki)"
fi

# 8. Prometheus + Grafana (metrics, alerting, dashboards)
if ! skip prometheus; then
  helm_install kube-prometheus-stack prometheus-community/kube-prometheus-stack monitoring \
    "${VALUES_DIR}/kube-prometheus-stack.yaml"
else
  info "Skipping kube-prometheus-stack (--skip prometheus)"
fi

# 9. Argo CD (GitOps continuous delivery)
if ! skip argocd; then
  helm_install argocd argo/argo-cd argocd \
    "${VALUES_DIR}/argo-cd.yaml"
else
  info "Skipping argocd (--skip argocd)"
fi

# 10. metrics-server (skip if managed by cloud provider)
case "${CLOUD}" in
  aws)
    info "Skipping metrics-server (EKS manages this as an addon)"
    ;;
  gcp)
    info "Skipping metrics-server (GKE Autopilot includes this)"
    ;;
  azure)
    info "Skipping metrics-server (AKS includes this by default)"
    ;;
  kind)
    if ! skip metricsServer; then
      helm_repo_add metrics-server https://kubernetes-sigs.github.io/metrics-server/
      helm repo update >/dev/null 2>&1
      helm_install metrics-server metrics-server/metrics-server kube-system \
        "${VALUES_DIR}/cert-manager.yaml" \
        --set "args[0]=--kubelet-insecure-tls"
    fi
    ;;
esac

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------

if ! ${DRY_RUN}; then
  echo ""
  info "Verifying installations..."

  for ns in cert-manager external-secrets envoy-gateway-system external-dns logging loki monitoring argocd; do
    PODS=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${PODS}" -gt 0 ]]; then
      success "  ${ns}: ${PODS} pod(s)"
    else
      warn "  ${ns}: no pods found"
    fi
  done

  if [[ "${CLOUD}" == "aws" ]]; then
    PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l | tr -d ' ')
    success "  aws-load-balancer-controller: ${PODS} pod(s)"
  fi
fi

echo ""
success "Base platform installed for ${CLOUD}/${ENV}"
echo ""
info "Next steps:"
echo "  1. Create ClusterIssuer for cert-manager (TLS)"
echo "  2. Create ClusterSecretStore for external-secrets"
echo "  3. Configure Argo CD app-of-apps for your workloads"
echo "  4. Access Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
