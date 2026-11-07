
#!/usr/bin/env bash

set -Eeuo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------
CLUSTER_NAME="demo"
KUBE_CONTEXT="kind-demo"
NAMESPACE="demo"
RELEASE_NAME="demo"

IMAGE_REPOSITORY="btarunkumar/enterprise-demo-service"
IMAGE_TAG="v1.0"
IMAGE="${IMAGE_REPOSITORY}:${IMAGE_TAG}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${REPO_ROOT}/chart"
SERVICE_DIR="${REPO_ROOT}/service"

INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"

echo "================================================"
echo " Enterprise Bot - Part 3 Automated Setup"
echo "================================================"

# --------------------------------------------------
# 1. Check prerequisites
# --------------------------------------------------
echo "[1/8] Checking prerequisites..."

for cmd in docker kind kubectl helm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $cmd"
        exit 1
    fi
done

docker info >/dev/null

if [[ ! -f "${SERVICE_DIR}/Dockerfile" ]]; then
    echo "ERROR: Dockerfile not found."
    exit 1
fi

if [[ ! -f "${CHART_DIR}/Chart.yaml" ]]; then
    echo "ERROR: Helm chart not found."
    exit 1
fi

echo "All prerequisites are available."

# --------------------------------------------------
# 2. Create or reuse Kind cluster
# --------------------------------------------------
echo "[2/8] Checking Kind cluster..."

if kind get clusters | grep -Fxq "$CLUSTER_NAME"; then
    echo "Kind cluster '${CLUSTER_NAME}' already exists. Reusing it."
else
    echo "Creating Kind cluster '${CLUSTER_NAME}'..."

    KIND_CONFIG="$(mktemp)"

    cat > "$KIND_CONFIG" <<'KIND_EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
KIND_EOF

    kind create cluster \
        --name "$CLUSTER_NAME" \
        --config "$KIND_CONFIG" \
        --wait 120s

    rm -f "$KIND_CONFIG"
fi

# Use the required cluster explicitly.
kubectl config get-contexts "$KUBE_CONTEXT" >/dev/null

echo "Using Kubernetes context: ${KUBE_CONTEXT}"

# --------------------------------------------------
# 3. Install ingress-nginx
# --------------------------------------------------
echo "[3/8] Installing ingress-nginx..."

kubectl --context "$KUBE_CONTEXT" apply \
    -f "$INGRESS_MANIFEST"

kubectl --context "$KUBE_CONTEXT" rollout status \
    deployment/ingress-nginx-controller \
    --namespace ingress-nginx \
    --timeout=300s

echo "Ingress controller is ready."

# --------------------------------------------------
# 4. Build Docker image
# --------------------------------------------------
echo "[4/8] Building application image..."

docker build \
    -t "$IMAGE" \
    -f "${SERVICE_DIR}/Dockerfile" \
    "$SERVICE_DIR"

# --------------------------------------------------
# 5. Load image into Kind
# --------------------------------------------------
echo "[5/8] Loading image into Kind cluster..."

kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"

# --------------------------------------------------
# 6. Validate Helm chart
# --------------------------------------------------
echo "[6/8] Validating Helm chart..."

helm lint "$CHART_DIR"

# --------------------------------------------------
# 7. Install or upgrade Helm release
# --------------------------------------------------
echo "[7/8] Deploying Helm release..."

helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
    --kube-context "$KUBE_CONTEXT" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --set image.repository="$IMAGE_REPOSITORY" \
    --set image.tag="$IMAGE_TAG" \
    --set image.pullPolicy=IfNotPresent \
    --wait \
    --timeout 300s

# --------------------------------------------------
# 8. Verify deployment readiness
# --------------------------------------------------
echo "[8/8] Verifying application deployment..."

kubectl --context "$KUBE_CONTEXT" wait \
    --namespace "$NAMESPACE" \
    --for=condition=Available \
    deployment \
    -l app.kubernetes.io/instance="$RELEASE_NAME" \
    --timeout=300s

echo
echo "================================================"
echo " SETUP COMPLETED SUCCESSFULLY"
echo "================================================"

echo
echo "Kind clusters:"
kind get clusters

echo
echo "Application resources:"
kubectl --context "$KUBE_CONTEXT" get all -n "$NAMESPACE"

echo
echo "Ingress:"
kubectl --context "$KUBE_CONTEXT" get ingress -n "$NAMESPACE"

echo
echo "Helm release:"
helm list --kube-context "$KUBE_CONTEXT" -n "$NAMESPACE"

echo
echo "Application image: $IMAGE"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo
echo "================================================"

