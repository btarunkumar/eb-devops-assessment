# Enterprise DevOps Assessment – Complete Implementation & Validation Reference

## Overview

This repository contains the implementation and validation reference for a four-part DevOps assessment covering application containerization, Kubernetes deployment, infrastructure automation, and Kubernetes troubleshooting.

The assessment demonstrates practical knowledge of:

- Python Flask application development.
- Docker image creation and container security.
- Helm chart development and Kubernetes resource management.
- Kubernetes networking, health probes, and horizontal scaling.
- Kind cluster provisioning and deployment automation.
- Shell scripting, idempotency, and error handling.
- Kubernetes troubleshooting and root cause analysis.
- Resource management, RBAC, and application connectivity.

## Assessment Structure

| Part | Assessment | Primary Technologies |
|---|---|---|
| Part 1 | Application Development and Docker Containerization | Python, Flask, Docker, Gunicorn |
| Part 2 | Kubernetes Deployment Using Helm | Kubernetes, Helm, NGINX Ingress |
| Part 3 | Kubernetes Environment Automation | Bash, Kind, Docker, kubectl, Helm |
| Part 4 | Kubernetes Troubleshooting and Debugging | Kubernetes, Helm, RBAC, Jobs, Linux |

---

# Part 1 – Application Development and Docker Containerization

## 1. Objective

Develop a lightweight HTTP application using Python Flask and package it into a secure, reproducible Docker image.

The application exposes two HTTP endpoints:

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Returns application name, version, and container/pod hostname. |
| `/healthz` | GET | Returns application health status. |

Application metadata is configurable through environment variables without modifying the application source code.

## 2. Project Structure

```text
service/
├── app.py
├── Dockerfile
├── requirements.txt
└── .dockerignore
```

## 3. Application Implementation

### 3.1 Flask Application

File: `service/app.py`

```python
import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "app": os.getenv("APP_NAME", "enterprise-demo"),
        "version": os.getenv("VERSION", "1.0.0"),
        "pod": socket.gethostname()
    }), 200


@app.route("/healthz", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy"
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

**Implementation details:**

- Flask handles HTTP requests.
- `APP_NAME` defines the application name.
- `VERSION` defines the application version.
- `socket.gethostname()` identifies the running container or Kubernetes pod.
- `/healthz` provides an application health endpoint.
- The application listens on port `8080`.
- Gunicorn is used as the production application server.

### 3.2 Python Dependencies

File: `service/requirements.txt`

```text
Flask==3.1.1
gunicorn==23.0.0
```

Dependencies are pinned to specific versions to improve build reproducibility.

### 3.3 Multi-Stage Dockerfile

File: `service/Dockerfile`

```dockerfile
# Stage 1: Build dependencies
FROM python:3.12.10-slim-bookworm AS builder

WORKDIR /build

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --prefix=/install \
    -r requirements.txt


# Stage 2: Runtime image
FROM python:3.12.10-slim-bookworm AS runtime

WORKDIR /app

# Copy installed dependencies
COPY --from=builder /install /usr/local

# Copy application source
COPY app.py .

# Create dedicated non-root application user
RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 \
    --gid 10001 \
    --no-create-home \
    --shell /usr/sbin/nologin \
    appuser

# Set application directory ownership
RUN chown -R appuser:appuser /app

# Run application without root privileges
USER 10001:10001

# Expose application port
EXPOSE 8080

# Start Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
```

**Docker implementation decisions:**

| Requirement | Implementation |
|---|---|
| Build strategy | Multi-stage build |
| Base image | `python:3.12.10-slim-bookworm` |
| Dependency installation | pip |
| Dependency versions | Pinned |
| Runtime user | appuser |
| User ID | 10001 |
| Group ID | 10001 |
| Working directory | `/app` |
| Application port | 8080 |
| Application server | Gunicorn |
| Worker processes | 2 |

The builder stage installs Python dependencies. The runtime stage copies the installed dependencies and application source without retaining the builder's intermediate files.

This reduces unnecessary build artifacts in the final runtime image.

### 3.4 Docker Build Context Exclusions

File: `service/.dockerignore`

```text
__pycache__/
*.py[cod]
*.pyo
*.pyd

.Python
.venv/
venv/
env/

.git/
.gitignore

.pytest_cache/
.mypy_cache/
.coverage

.env
.env.*

*.log
.DS_Store
```

The Docker ignore file excludes unnecessary development files, Git metadata, local environments, environment files, and Python cache directories.

## 4. Docker Image Build and Validation

Navigate to the repository:

```bash
cd ~/eb-devops-assessment
```

### 4.1 Build the Docker Image

```bash
docker build -t eb-demo-service:1.0 ./service
```

This builds the application image using the Dockerfile inside `service/`.

### 4.2 Verify the Image

```bash
docker images | grep eb-demo-service
```

Inspect image configuration:

```bash
docker image inspect eb-demo-service:1.0
```

Verify the configured runtime user:

```bash
docker image inspect eb-demo-service:1.0 \
  --format '{{.Config.User}}'
```

Expected:

```text
10001:10001
```

Verify the exposed port:

```bash
docker image inspect eb-demo-service:1.0 \
  --format '{{json .Config.ExposedPorts}}'
```

Expected:

```json
{"8080/tcp":{}}
```

### 4.3 Start the Container

```bash
docker run -d \
  --name eb-demo-test \
  -p 8080:8080 \
  -e APP_NAME=EnterpriseBot \
  -e VERSION=1.0.0 \
  eb-demo-service:1.0
```

Environment variables configure the application at runtime.

Verify the container:

```bash
docker ps
```

Inspect its runtime configuration:

```bash
docker inspect eb-demo-test \
  --format 'User={{.Config.User}} Status={{.State.Status}}'
```

Expected:

```text
User=10001:10001 Status=running
```

### 4.4 Validate Application Endpoints

Test the root endpoint:

```bash
curl -i http://localhost:8080/
```

Expected HTTP status:

```text
HTTP/1.1 200 OK
Content-Type: application/json
```

Example response:

```json
{
  "app": "EnterpriseBot",
  "pod": "<container-hostname>",
  "version": "1.0.0"
}
```

Test the health endpoint:

```bash
curl -i http://localhost:8080/healthz
```

Expected response:

```json
{
  "status": "healthy"
}
```

### 4.5 Verify Non-Root Execution

```bash
docker exec eb-demo-test id
```

Expected:

```text
uid=10001(appuser) gid=10001(appuser)
```

This verifies that the application runs using its dedicated non-root identity.

### 4.6 Inspect Application Logs

```bash
docker logs eb-demo-test
```

Gunicorn should start and listen on:

```text
0.0.0.0:8080
```

### 4.7 Container Cleanup

```bash
docker rm -f eb-demo-test
```

Verify removal:

```bash
docker ps -a | grep eb-demo-test
```

No matching output indicates that the test container has been removed.

## 5. Previously Recorded Application Validation

During subsequent Kubernetes deployment validation, the application endpoints were tested successfully through port forwarding.

Root endpoint:

```bash
curl -i http://localhost:8080/
```

Previously recorded HTTP status:

```text
HTTP/1.1 200 OK
```

Previously recorded response:

```json
{
  "app": "enterprise-bot-demo",
  "pod": "89f89dd3f74b",
  "version": "1.0.0"
}
```

Health endpoint:

```bash
curl -i http://localhost:8080/healthz
```

Previously recorded response:

```json
{
  "status": "healthy"
}
```

These are recorded Kubernetes application responses, not claimed results from the separate Docker-only test.

## 6. Previously Identified Docker Image

An existing image was identified during project inspection:

| Property | Recorded Value |
|---|---|
| Repository | `btarunkumar/enterprise-demo-service` |
| Tag | `v1.0` |
| Image ID | `72cfa848a406` |
| Reported image size | 196 MB |
| Reported shared size | 47.6 MB |

This image is distinct from the assessment's local image tag:

```text
eb-demo-service:1.0
```

## 7. Part 1 Validation Summary

| Requirement | Implementation | Validation |
|---|---|---|
| Flask application | `app.py` | HTTP 200 recorded |
| Application metadata | Environment variables | Implemented |
| Container hostname | `socket.gethostname()` | Implemented |
| Health endpoint | `/healthz` | HTTP 200 recorded |
| Multi-stage build | Builder and runtime | Implemented |
| Pinned base image | Python 3.12.10 Slim Bookworm | Implemented |
| Pinned dependencies | requirements.txt | Implemented |
| Non-root execution | UID/GID 10001 | Configured |
| Docker ignore | `.dockerignore` | Implemented |
| Application port | 8080 | Configured |
| Gunicorn | Two workers | Configured |

## 8. Conclusion

Part 1 establishes the application containerization foundation for the remaining assessment.

The Flask application provides configurable metadata and a health-check endpoint. Docker packages the application using a multi-stage build, pinned dependencies, and a dedicated non-root runtime identity.

The resulting image provides a consistent application artifact for subsequent Kubernetes deployment.

---

# Part 2 – Kubernetes Deployment Using Helm

## 1. Objective

Develop a reusable and configurable Helm chart to deploy the containerized Python application into a Kubernetes cluster.

The objective is to manage Kubernetes resources through Helm templates rather than maintaining separate static deployment manifests.

The implementation covers:

- Application configuration.
- Deployment and replica management.
- Internal Kubernetes networking.
- External application access.
- Readiness and liveness probes.
- Resource requests and limits.
- ServiceAccount management.
- Horizontal Pod Autoscaling.
- Optional Gateway API routing.

The deployment environment used a local Kind Kubernetes cluster with the NGINX Ingress Controller.

## 2. Helm Chart Structure

The primary Helm chart is maintained in the repository-root `chart/` directory.

```text
chart/
├── Chart.yaml
├── values.yaml
├── .helmignore
└── templates/
    ├── _helpers.tpl
    ├── configmap.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── httproute.yaml
    ├── hpa.yaml
    ├── serviceaccount.yaml
    ├── NOTES.txt
    └── tests/
        └── test-connection.yaml
```

### File Responsibilities

| File | Responsibility |
|---|---|
| `Chart.yaml` | Helm chart metadata and version information. |
| `values.yaml` | Default application and Kubernetes configuration. |
| `.helmignore` | Excludes unnecessary files from chart packaging. |
| `_helpers.tpl` | Reusable naming and labeling helpers. |
| `configmap.yaml` | Application configuration. |
| `deployment.yaml` | Application Deployment, replicas, probes, and resources. |
| `service.yaml` | Internal Kubernetes Service. |
| `ingress.yaml` | External HTTP routing through NGINX Ingress. |
| `httproute.yaml` | Optional Kubernetes Gateway API routing. |
| `hpa.yaml` | Horizontal Pod Autoscaler. |
| `serviceaccount.yaml` | Application ServiceAccount. |
| `NOTES.txt` | Post-installation information. |
| `tests/test-connection.yaml` | Helm connectivity test resource. |

## 3. Helm Chart Configuration

### 3.1 Chart Metadata

File: `chart/Chart.yaml`

The chart metadata defines:

- Chart name.
- Chart description.
- Chart version.
- Application version.

The metadata identifies the Helm package and its associated application release.

### 3.2 Default Values

File: `chart/values.yaml`

The values file provides centralized configuration for the chart.

Supported configuration includes:

- Replica count.
- Container image repository and tag.
- Image pull policy.
- Application name and version.
- Container port.
- Service type and port.
- Ingress configuration.
- Resource requests and limits.
- Readiness and liveness probes.
- ServiceAccount configuration.
- HPA configuration.

Required deployment defaults:

| Parameter | Value |
|---|---|
| Replica count | 2 |
| Container port | 8080 |
| Service type | ClusterIP |
| Service port | 80 |
| Target port | 8080 |
| Health endpoint | `/healthz` |
| Ingress class | nginx |
| Ingress hostname | `demo.local` |

The actual configuration is maintained in `chart/values.yaml`.

Changes can be introduced through Helm values overrides without directly modifying the templates.

## 4. Kubernetes Resource Implementation

### 4.1 ConfigMap

File: `chart/templates/configmap.yaml`

The ConfigMap stores application configuration separately from the container image.

Application metadata is configurable through Helm values.

The configuration is made available to the application through:

1. Environment variables.
2. Mounted configuration files.

This approach separates deployment configuration from application packaging.

### 4.2 Deployment

File: `chart/templates/deployment.yaml`

The Deployment manages the desired application replicas.

The template supports:

- Configurable replica count.
- Container image repository and tag.
- Image pull policy.
- Container port 8080.
- Environment variables sourced from ConfigMap.
- ConfigMap volume mounting.
- CPU and memory requests.
- CPU and memory limits.
- Readiness probes.
- Liveness probes.
- ServiceAccount association.

The health endpoint is:

```text
/healthz
```

**Readiness probe:** Determines whether a container is ready to receive application traffic.

**Liveness probe:** Determines whether a container should be restarted because its application process is unhealthy.

### 4.3 Kubernetes Service

File: `chart/templates/service.yaml`

The Service provides internal network access to application Pods.

Configuration:

| Parameter | Value |
|---|---|
| Service type | ClusterIP |
| Service port | 80 |
| Target port | 8080 |
| Container port | 8080 |

Traffic flow:

```text
Client
  |
  v
Kubernetes Service
  |
  | Port 80
  v
Application Pod
  |
  | Container Port 8080
  v
Flask Application
```

### 4.4 Ingress

File: `chart/templates/ingress.yaml`

The Ingress resource exposes the application through the NGINX Ingress Controller.

Configured hostname:

```text
demo.local
```

Incoming requests are routed through the Ingress Controller to the Kubernetes Service, which forwards traffic to the application Pods.

For local Kind testing, the hostname must resolve to the configured Kind ingress endpoint.

### 4.5 ServiceAccount

File: `chart/templates/serviceaccount.yaml`

The ServiceAccount provides an identity for the application Pods.

Its creation and association with the Deployment are configurable through Helm values.

### 4.6 Horizontal Pod Autoscaler

File: `chart/templates/hpa.yaml`

The HPA template provides horizontal scaling based on resource utilization.

Supported settings include:

- Minimum replica count.
- Maximum replica count.
- CPU utilization target.

CPU-based autoscaling requires:

- A functioning Metrics Server.
- CPU resource requests configured on the application containers.
- Valid HPA configuration.

### 4.7 HTTPRoute

File: `chart/templates/httproute.yaml`

The HTTPRoute template provides optional routing through the Kubernetes Gateway API.

This is an alternative to NGINX Ingress.

It requires Gateway API CRDs and a compatible Gateway controller when enabled.

## 5. Helm Chart Validation

Navigate to the repository:

```bash
cd ~/eb-devops-assessment
```

### 5.1 Helm Lint

Command executed:

```bash
helm lint ./chart
```

Actual recorded terminal output:

```text
==> Linting ./chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

**Result: Successful.**

The chart passed Helm lint validation without any chart failures.

The icon message is an optional recommendation.

### 5.2 Render Templates with Custom Values

Command executed:

```bash
helm template demo ./chart \
  --set replicaCount=3 \
  --set config.appName=assessment-service \
  --set config.version=2.5.0 \
  --set ingress.host=demo.local
```

Custom configuration:

| Parameter | Value |
|---|---|
| Release name | demo |
| Chart directory | `./chart` |
| Replica count | 3 |
| Application name | assessment-service |
| Application version | 2.5.0 |
| Ingress hostname | demo.local |

This demonstrates Helm's ability to render Kubernetes manifests using custom configuration.

### 5.3 Save Rendered Manifests

```bash
helm template demo ./chart \
  --set replicaCount=3 \
  --set config.appName=assessment-service \
  --set config.version=2.5.0 \
  --set ingress.host=demo.local \
  > /tmp/demo-rendered.yaml
```

Inspect generated resource types:

```bash
grep -nE '^kind:' /tmp/demo-rendered.yaml
```

Inspect custom values:

```bash
grep -nE 'assessment-service|2.5.0|demo.local' \
  /tmp/demo-rendered.yaml
```

This provides an additional way to inspect generated manifests before deployment.

## 6. Helm Deployment

### 6.1 Install or Upgrade the Release

```bash
helm upgrade --install demo ./chart \
  --namespace demo \
  --create-namespace
```

Command breakdown:

| Option | Purpose |
|---|---|
| `upgrade --install` | Install or upgrade the release. |
| `demo` | Helm release name. |
| `./chart` | Local chart directory. |
| `--namespace demo` | Deployment namespace. |
| `--create-namespace` | Creates the namespace if missing. |

### 6.2 Verify Helm Release

```bash
helm list -n demo
```

### 6.3 Verify Kubernetes Resources

```bash
kubectl get all -n demo
```

Inspect individual resources:

```bash
kubectl get deployments -n demo

kubectl get pods -n demo -o wide

kubectl get services -n demo

kubectl get configmaps -n demo

kubectl get serviceaccounts -n demo

kubectl get ingress -n demo

kubectl get hpa -n demo
```

### 6.4 Inspect Ingress

```bash
kubectl describe ingress -n demo
```

### 6.5 Inspect Application Configuration

```bash
kubectl get configmaps -n demo -o yaml

kubectl get deployment -n demo -o yaml

helm get values demo -n demo --all

helm get manifest demo -n demo
```

These commands help verify the configuration applied through Helm.

## 7. Application Access and Validation

### 7.1 Service Port Forwarding

First, identify the Service name:

```bash
kubectl get svc -n demo
```

Start port forwarding:

```bash
kubectl port-forward -n demo \
  svc/<service-name> 8082:80
```

Keep the port-forward process running.

In another terminal:

```bash
curl -i http://localhost:8082/
```

Check application health:

```bash
curl -i http://localhost:8082/healthz
```

Expected health response:

```json
{
  "status": "healthy"
}
```

The health endpoint should return HTTP 200.

### 7.2 Verify Ingress Controller

Previously recorded command:

```bash
kubectl get pods -n ingress-nginx
```

Recorded output:

```text
NAME                                        READY   STATUS    RESTARTS
ingress-nginx-controller-596f5b6bcf-6zj5r   1/1     Running   0
```

This confirms that the NGINX Ingress Controller was running during the recorded session.

### 7.3 Verify Kind Cluster

Command:

```bash
kubectl get nodes
```

Previously recorded output:

```text
NAME                 STATUS   ROLES           AGE   VERSION
demo-control-plane   Ready    control-plane   74s   v1.37.0
```

The Kind control-plane node was in the Ready state.

## 8. Kubernetes Troubleshooting

### 8.1 Inspect Pod Status

```bash
kubectl get pods -n demo -o wide
```

### 8.2 Inspect Pod Details

```bash
kubectl describe pod <pod-name> -n demo
```

### 8.3 Inspect Application Logs

```bash
kubectl logs <pod-name> -n demo
```

For a previous container instance:

```bash
kubectl logs <pod-name> -n demo --previous
```

### 8.4 Inspect Kubernetes Events

```bash
kubectl get events -n demo \
  --sort-by=.metadata.creationTimestamp
```

### 8.5 Inspect Deployment

```bash
kubectl describe deployment -n demo
```

### 8.6 Inspect Service Endpoints

```bash
kubectl get endpoints -n demo

kubectl get endpointslices -n demo
```

If a Service has no endpoints, investigate its selector and the labels on the application Pods.

### 8.7 Inspect HPA

```bash
kubectl get hpa -n demo

kubectl describe hpa -n demo
```

### 8.8 Inspect Resource Utilization

```bash
kubectl top pods -n demo
```

This requires a working Metrics Server.

### 8.9 Revalidate Helm Templates

```bash
helm lint ./chart

helm template demo ./chart
```

## 9. Part 2 Validation Summary

| Requirement | Implementation | Validation |
|---|---|---|
| ConfigMap | `configmap.yaml` | Resource inspection |
| Deployment | `deployment.yaml` | Deployment inspection |
| Service | `service.yaml` | Service inspection |
| Ingress | `ingress.yaml` | Ingress inspection |
| ServiceAccount | `serviceaccount.yaml` | Resource inspection |
| HPA | `hpa.yaml` | HPA inspection |
| Default replicas | 2 | Values inspection |
| Container port | 8080 | Deployment inspection |
| Service port | 80 | Service inspection |
| Target port | 8080 | Service inspection |
| Health probes | `/healthz` | Deployment inspection |
| Application metadata | Helm configurable | ConfigMap inspection |
| Mounted configuration | ConfigMap volume | Pod specification |
| Environment variables | ConfigMap references | Deployment inspection |
| Resource requests | CPU and memory | Deployment inspection |
| Resource limits | CPU and memory | Deployment inspection |
| Ingress hostname | `demo.local` | Ingress inspection |
| Helm lint | Passed | Zero chart failures |
| Custom rendering | Executed | Custom overrides supplied |
| Kubernetes deployment | Installed during assessment | Recorded cluster checks |

## 10. Conclusion

Part 2 demonstrates how Helm can package and deploy a containerized application into Kubernetes using reusable templates and centralized configuration.

The implementation supports configurable application metadata, replicas, probes, resource allocation, Service networking, Ingress routing, and optional horizontal scaling.

Helm lint completed successfully with zero chart failures, and custom configuration overrides were supplied during template rendering.

The resulting chart provides the deployment foundation for the automation and troubleshooting exercises in Parts 3 and 4.

---

# Part 3 – Kubernetes Environment Automation

## 1. Objective

Automate local Kubernetes environment provisioning and application deployment through a repository-root `setup.sh` script.

The script is designed to reduce manual setup operations by combining Kind, Docker, kubectl, NGINX Ingress, and Helm into a repeatable deployment workflow.

The primary objectives are:

- Validate system prerequisites.
- Create or reuse a Kind cluster.
- Configure the Kubernetes context.
- Install or reuse the NGINX Ingress Controller.
- Build the application Docker image.
- Load the image into Kind.
- Create or reuse the application namespace.
- Install or upgrade the Helm release.
- Verify deployment readiness.
- Handle failures with meaningful diagnostic messages.

## 2. Repository Structure

```text
eb-devops-assessment/
├── setup.sh
├── service/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── lab/
    ├── scenario.sh
    ├── FINDINGS.md
    ├── broken-chart/
    └── cluster-state/
```

## 3. Automation Workflow

The intended automation sequence is:

```text
Start setup.sh
      |
      v
Validate prerequisites
      |
      v
Check Kind cluster
      |
      +---- Missing ----> Create cluster
      |
      +---- Exists -----> Reuse cluster
      |
      v
Configure kind-demo context
      |
      v
Check NGINX Ingress
      |
      +---- Missing ----> Install controller
      |
      +---- Available --> Reuse controller
      |
      v
Build Docker image
      |
      v
Load image into Kind
      |
      v
Create or reuse demo namespace
      |
      v
Helm upgrade --install
      |
      v
Verify Deployment and Pods
      |
      v
Report success or failure
```

## 4. Automation Components

### 4.1 Prerequisite Validation

The script checks that the required commands are available:

- Docker
- Kind
- kubectl
- Helm
- Bash

Missing prerequisites should result in a clear error message and terminate the execution.

### 4.2 Kind Cluster Management

The cluster name is:

```text
demo
```

The script checks whether the cluster already exists.

If it does not exist, it creates the cluster.

If it exists, the script reuses the existing environment instead of unnecessarily deleting or recreating it.

### 4.3 Kubernetes Context

The expected Kubernetes context is:

```text
kind-demo
```

The script should explicitly select this context before executing deployment operations.

### 4.4 NGINX Ingress Controller

The script checks whether the NGINX Ingress Controller is already available.

If it is missing, the controller is installed.

If it is already available, the script reuses the existing installation.

The controller must become Ready before application ingress validation.

### 4.5 Docker Image Build

The application image is built from:

```text
./service
```

The script should use a consistent image name and tag across the build, Kind image-loading, and Helm deployment configuration.

### 4.6 Image Loading into Kind

Kind uses containerd inside its node containers.

A Docker image built on the host is not automatically available to workloads inside the cluster.

Therefore, the locally built image must be loaded into the Kind cluster.

This is performed using:

```bash
kind load docker-image <image-name>:<tag> \
  --name demo
```

The Helm chart must reference the same image name and tag.

For locally loaded images, the image pull policy must also be configured appropriately.

### 4.7 Namespace Management

The application namespace is:

```text
demo
```

The script creates the namespace if it does not already exist.

### 4.8 Helm Deployment

The Helm release is:

```text
demo
```

Deployment command:

```bash
helm upgrade --install demo ./chart \
  --namespace demo \
  --create-namespace
```

This supports both initial installation and subsequent upgrades.

## 5. Idempotency and Error Handling

Idempotency means repeated executions should converge on the intended environment without unnecessarily recreating existing resources.

The automation should follow these principles:

| Component | Idempotent Behavior |
|---|---|
| Prerequisites | Validate availability on every execution |
| Kind cluster | Create only when missing |
| Kubernetes context | Select the expected context |
| Ingress Controller | Install only when unavailable |
| Docker image | Rebuild from current application source |
| Kind image | Load the required image into the cluster |
| Namespace | Create only when missing |
| Helm release | Use `helm upgrade --install` |
| Deployment | Verify desired readiness |
| Failure handling | Stop on critical errors and report the failing step |

Recommended shell error-handling approach:

```bash
set -Eeuo pipefail
```

This enables stricter handling of command failures, unset variables, and pipeline errors.

The script should avoid deleting existing cluster resources unnecessarily.

## 6. Setup Script Execution

Navigate to the repository:

```bash
cd ~/eb-devops-assessment
```

Make the script executable:

```bash
chmod +x setup.sh
```

Validate shell syntax:

```bash
bash -n setup.sh
```

Execute the automation:

```bash
./setup.sh
```

The expected result is a prepared Kind environment with the application deployed through Helm.

## 7. Idempotency Validation

Execute the script a second time:

```bash
./setup.sh
```

The second execution should:

- Detect the existing Kind cluster.
- Reuse the existing Kubernetes environment.
- Reuse an available Ingress Controller.
- Reuse the application namespace.
- Load the required image.
- Upgrade or reuse the Helm release.
- Verify application readiness.
- Avoid unnecessary cluster recreation.

**Important:** The exact successful second-run terminal output was not preserved in the available assessment session history. The second execution should be captured before treating idempotency as independently verified.

## 8. Kubernetes Environment Verification

### 8.1 Verify Active Context

```bash
kubectl config current-context
```

Previously recorded output:

```text
kind-demo
```

### 8.2 Verify Kubernetes Nodes

```bash
kubectl get nodes
```

Previously recorded output:

```text
NAME                 STATUS   ROLES           AGE   VERSION
demo-control-plane   Ready    control-plane   ...   v1.37.0
```

The Kind control-plane node was reported as Ready.

## 9. Application Deployment Verification

### 9.1 Verify Application Pods

```bash
kubectl get pods -n demo -o wide
```

Previously recorded results:

- Two application Pods were deployed in the `demo` namespace.
- Both application Pods reached Running and Ready.
- The NGINX Ingress Controller Pod was also running.

### 9.2 Verify Helm Release

```bash
helm list -n demo
```

Previously recorded Helm release details:

| Field | Recorded Value |
|---|---|
| Release name | `demo` |
| Namespace | `demo` |
| Revision | 1 |
| Status | deployed |
| Chart | `enterprise-demo-0.1.0` |
| Application version | `1.0.0` |

### 9.3 Additional Verification Commands

```bash
kubectl get deployments -n demo

kubectl get services -n demo

kubectl get ingress -n demo

kubectl get pods -n ingress-nginx

helm status demo -n demo
```

## 10. Troubleshooting Commands

### Check Kind Cluster

```bash
kind get clusters
```

### Check Kubernetes Context

```bash
kubectl config get-contexts
kubectl config current-context
```

### Check Node Readiness

```bash
kubectl get nodes -o wide
```

### Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx

kubectl describe pods -n ingress-nginx
```

### Check Application Deployment

```bash
kubectl get deployments -n demo

kubectl get pods -n demo -o wide
```

### Check Helm Release

```bash
helm status demo -n demo

helm get values demo -n demo --all

helm get manifest demo -n demo
```

### Inspect Application Logs

```bash
kubectl logs -n demo deployment/<deployment-name>
```

### Inspect Events

```bash
kubectl get events -n demo \
  --sort-by=.metadata.creationTimestamp
```

### Verify Image Availability

```bash
docker images

docker exec demo-control-plane crictl images
```

The image name and tag inside Kind must match the image referenced by the Helm chart.

## 11. Part 3 Validation Summary

| Requirement | Implementation | Evidence |
|---|---|---|
| Root-level setup script | `setup.sh` | Script location identified |
| Prerequisite checks | Docker, Kind, kubectl, Helm | Intended automation |
| Kind cluster management | Create or reuse | Ready node recorded |
| Kubernetes context | `kind-demo` | Actual output recorded |
| NGINX Ingress | Install or reuse | Running Pod recorded |
| Docker build | Build application image | Automation step |
| Kind image loading | Load local image | Automation step |
| Namespace | `demo` | Deployment environment |
| Helm deployment | `upgrade --install` | Deployed release recorded |
| Application replicas | Two | Both Ready, previously recorded |
| Second-run idempotency | Reuse existing resources | Requires captured second-run evidence |

## 12. Conclusion

Part 3 introduces repeatable Kubernetes environment provisioning and application deployment through shell automation.

Combining Kind, Docker, NGINX Ingress, kubectl, and Helm reduces manual configuration and establishes a consistent deployment workflow.

The previously recorded results confirm the `kind-demo` context, a Ready Kubernetes node, two Ready application Pods, a running Ingress Controller, and a deployed Helm release.

The final automation evidence should additionally include successful first-run and second-run execution logs to demonstrate complete idempotency.

---

# Part 4 – Kubernetes Troubleshooting and Debugging

## 1. Objective

Investigate an intentionally misconfigured Kubernetes environment, identify the underlying causes of workload failures, implement targeted Helm chart corrections, and validate the results using the supplied acceptance-testing script.

The exercise focuses on practical Kubernetes troubleshooting, including:

- Workload lifecycle management.
- Kubernetes Jobs.
- Container security contexts.
- Image user configuration.
- Resource requests and limits.
- Namespace resource constraints.
- ServiceAccount and RBAC permissions.
- Service selectors and networking.
- Application-level health checks.
- Helm template validation.

The original assessment environment was preserved, with corrections restricted to the supplied `lab/broken-chart/` directory.

## 2. Assessment Environment

### 2.1 Supplied Directory Structure

```text
lab/
├── scenario.sh
├── FINDINGS.md
├── broken-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── backend.yaml
│       ├── gateway.yaml
│       ├── metrics.yaml
│       ├── migrate-job.yaml
│       ├── rbac.yaml
│       ├── reporter.yaml
│       └── worker.yaml
└── cluster-state/
    ├── namespace.yaml
    └── limits.yaml
```

### 2.2 Assessment Configuration

| Component | Configuration |
|---|---|
| Namespace | `debug-lab` |
| Helm release | `debug-lab` |
| Helm chart | `lab/broken-chart` |
| Namespace configuration | `lab/cluster-state/` |
| Verification script | `lab/scenario.sh` |
| Findings document | `lab/FINDINGS.md` |

### 2.3 Assessment Constraint

The following supplied files were preserved:

- `scenario.sh`
- `cluster-state/namespace.yaml`
- `cluster-state/limits.yaml`

Troubleshooting corrections were implemented within:

```text
lab/broken-chart/
```

This ensured that the supplied assessment scenario and namespace constraints remained unchanged.

## 3. Initial Investigation

Navigate to the assessment directory:

```bash
cd ~/eb-devops-assessment/lab
```

Inspect the supplied files:

```bash
ls -lrth

cat scenario.sh

cat FINDINGS.md

find broken-chart -maxdepth 3 -type f -print
```

### 3.1 Understand the Scenario Script

The supplied script supports three operations:

```bash
./scenario.sh up

./scenario.sh verify

./scenario.sh reset
```

| Operation | Purpose |
|---|---|
| `up` | Applies namespace and LimitRange configuration, then installs or upgrades the Helm chart. |
| `verify` | Checks workload readiness, migration completion, RBAC, and application connectivity. |
| `reset` | Removes assessment lab resources. |

The supplied verification script serves as the acceptance test for the troubleshooting exercise.

## 4. Troubleshooting and Root Cause Analysis

The investigation covered six primary areas.

### 4.1 Issue 1 – Migration Job Configuration

**Problem area:** Kubernetes Job restart policy.

Inspect the migration template:

```bash
cat broken-chart/templates/migrate-job.yaml
```

The original template contained:

```yaml
spec:
  backoffLimit: {{ .Values.migrate.backoffLimit }}
  template:
    spec:
      restartPolicy: Always
```

**Root cause:**

A Kubernetes Job represents a finite task that must terminate successfully.

The Pod restart policy for a Job must be either:

- `Never`
- `OnFailure`

`Always` is not valid for a Job Pod.

**Correction:**

Use an appropriate Job restart policy:

```yaml
restartPolicy: Never
```

Alternatively, use `OnFailure` where the intended retry behavior requires container restarts.

**Validation:**

```bash
kubectl get jobs -n debug-lab

kubectl describe job migrate -n debug-lab

kubectl get pods -n debug-lab
```

**Expected acceptance condition:**

```text
1 successful Job completion
```

The migration Job must complete rather than remain active or repeatedly restart.

### 4.2 Issue 2 – Container Security Context and Image User

**Problem area:** Non-root container execution.

Inspect workload security configurations:

```bash
grep -R -n -A12 -B3 "securityContext" \
  broken-chart/templates/
```

The supplied security restrictions included:

```yaml
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

Inspect the local image configuration:

```bash
docker inspect eb-demo-service:v1.0 \
  --format '{{.Config.User}}'
```

For an image available inside the Kind cluster:

```bash
docker exec demo-control-plane \
  crictl inspecti docker.io/ebinterview/eb-debug-app:1.0.1
```

**Root cause investigation:**

Kubernetes requires a container configured with `runAsNonRoot: true` to execute under a non-root user identity.

If the image does not specify a compatible non-root user, the container can fail to start.

The image's configured user and the Pod's security context must therefore be compatible.

**Correction:**

- Ensure the container image specifies a valid non-root user.
- Retain `runAsNonRoot: true`.
- Retain disabled privilege escalation.
- Drop unnecessary Linux capabilities.
- Retain the read-only root filesystem where supported.
- Provide writable temporary volumes if the application requires temporary write access.

**Security principle:**

Do not resolve a security-context failure by disabling non-root execution or running the application as root.

**Validation:**

```bash
kubectl get pods -n debug-lab

kubectl describe pod <pod-name> -n debug-lab

kubectl logs <pod-name> -n debug-lab
```

Where the container is running:

```bash
kubectl exec -n debug-lab <pod-name> -- id
```

### 4.3 Issue 3 – Resource Requests, Limits, and Scheduling

**Problem area:** Namespace resource constraints.

Inspect the supplied namespace configuration:

```bash
cat cluster-state/limits.yaml
```

Inspect Kubernetes resource controls:

```bash
kubectl get resourcequota -n debug-lab

kubectl get limitrange -n debug-lab

kubectl describe limitrange debug-lab-guardrails \
  -n debug-lab
```

The supplied LimitRange defines:

| Resource | Default Request | Default Limit | Maximum |
|---|---:|---:|---:|
| CPU | 50m | 200m | 1 CPU |
| Memory | 64Mi | 128Mi | 512Mi |

**Root cause investigation:**

Workload requests and limits must be compatible with namespace-level resource constraints.

Incorrect resource configuration can cause:

- Pod admission failures.
- Resource limit validation errors.
- Scheduling failures.
- CPU throttling.
- Memory pressure.
- Out-of-memory termination.

**Correction:**

Configure suitable CPU and memory requests and limits through Helm values.

Ensure that every container remains within the supplied namespace maximums.

Preserve the original:

```text
cluster-state/limits.yaml
```

**Validation:**

```bash
kubectl get pods -n debug-lab

kubectl describe pods -n debug-lab

kubectl get limitrange -n debug-lab

kubectl get events -n debug-lab \
  --sort-by=.metadata.creationTimestamp
```

### 4.4 Issue 4 – RBAC and ServiceAccount Permissions

**Problem area:** Incorrect RoleBinding subject.

Inspect the reporter workload:

```bash
cat broken-chart/templates/reporter.yaml
```

Inspect RBAC configuration:

```bash
cat broken-chart/templates/rbac.yaml
```

The original RoleBinding referenced:

```yaml
subjects:
  - kind: ServiceAccount
    name: default
    namespace: {{ .Release.Namespace }}
```

However, the reporter Deployment used a separately configured ServiceAccount:

```yaml
serviceAccountName: {{ .Values.reporter.serviceAccountName }}
```

**Root cause:**

The RoleBinding granted permissions to the `default` ServiceAccount, while the reporter workload used the `reporter` ServiceAccount.

Kubernetes permissions granted to one ServiceAccount are not automatically inherited by another.

Consequently, the reporter could fail when attempting to list Pods.

**Correction:**

Bind the `reporter-read` Role to the same ServiceAccount used by the reporter Deployment:

```yaml
subjects:
  - kind: ServiceAccount
    name: reporter
    namespace: {{ .Release.Namespace }}
```

The exact name should remain consistent with the Helm value used by the reporter Deployment.

**Validation:**

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:debug-lab:reporter \
  -n debug-lab
```

Expected:

```text
yes
```

This verifies that the reporter ServiceAccount has the required permission.

**Security principle:**

Grant only the Kubernetes permissions required by the workload.

Avoid unnecessary cluster-wide privileges.

### 4.5 Issue 5 – Services, Selectors, and Networking

**Problem area:** Kubernetes Service discovery and application connectivity.

Inspect Services:

```bash
kubectl get svc -n debug-lab -o wide
```

Inspect Pod labels:

```bash
kubectl get pods -n debug-lab --show-labels
```

Inspect Service endpoints:

```bash
kubectl get endpoints -n debug-lab

kubectl get endpointslices -n debug-lab
```

**Root cause investigation:**

A Kubernetes Service forwards traffic to Pods selected through matching labels.

Incorrect selectors, missing Pod labels, or mismatched ports can result in unavailable application endpoints.

The investigation focused on:

- Service selectors matching Pod labels.
- Correct Service ports.
- Correct target ports.
- Application listening ports.
- Backend DNS resolution.
- Gateway-to-backend connectivity.
- Reporter access to the expected Kubernetes resources.

**Correction:**

Ensure that Service selectors match the corresponding Pod template labels.

Ensure that Service ports and target ports match the actual application listening ports.

Preserve the intended internal application communication.

**Validation:**

```bash
kubectl get svc,endpoints -n debug-lab

kubectl get endpointslices -n debug-lab

kubectl get pods -n debug-lab -o wide
```

The supplied scenario's in-cluster application probes provide additional validation of the communication paths.

### 4.6 Issue 6 – Helm Template and Workload Configuration

**Problem area:** Configuration inconsistencies across the supplied Helm chart.

Inspect chart values:

```bash
cat broken-chart/values.yaml
```

Inspect workload templates:

```bash
cat broken-chart/templates/backend.yaml

cat broken-chart/templates/gateway.yaml

cat broken-chart/templates/worker.yaml

cat broken-chart/templates/metrics.yaml
```

**Investigation areas:**

- Helm values references.
- Deployment specifications.
- Job specifications.
- Pod labels and Service selectors.
- Container ports.
- Service target ports.
- Readiness probes.
- Image repository and tag.
- Resource requests and limits.
- Container security contexts.
- ServiceAccount references.

**Correction:**

Apply targeted corrections to the affected Helm templates and their corresponding values.

Keep the workload definitions consistent and ensure that all required Kubernetes resources can be rendered and deployed.

## 5. Applying the Corrections

After completing the investigation and modifying the supplied Helm chart, redeploy the assessment environment.

Navigate to the lab directory:

```bash
cd ~/eb-devops-assessment/lab
```

Run:

```bash
./scenario.sh up
```

The scenario uses the equivalent deployment operations:

```bash
kubectl apply -f cluster-state/

helm upgrade --install debug-lab ./broken-chart \
  -n debug-lab
```

The `upgrade --install` operation supports both initial deployment and subsequent chart corrections.

This allows the same deployment procedure to be repeated after fixing Helm templates.

## 6. Deployment and Workload Verification

### 6.1 Verify Pods

```bash
kubectl get pods -n debug-lab -o wide
```

Check that the required workloads reach the Ready state.

### 6.2 Verify Deployments

```bash
kubectl get deployments -n debug-lab
```

### 6.3 Verify Migration Job

```bash
kubectl get jobs -n debug-lab

kubectl describe job migrate -n debug-lab
```

Confirm that the migration Job completes successfully.

### 6.4 Verify Services and Endpoints

```bash
kubectl get svc,endpoints -n debug-lab
```

### 6.5 Verify Kubernetes Events

```bash
kubectl get events -n debug-lab \
  --sort-by=.metadata.creationTimestamp
```

### 6.6 Inspect Application Logs

```bash
kubectl logs <pod-name> -n debug-lab
```

Inspect previous container logs when necessary:

```bash
kubectl logs <pod-name> -n debug-lab --previous
```

### 6.7 Verify RBAC

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:debug-lab:reporter \
  -n debug-lab
```

The expected result is:

```text
yes
```

## 7. Final Scenario Verification

After redeploying the corrected chart, execute the supplied acceptance test:

```bash
./scenario.sh verify
```

The verification script checks the following conditions:

| Component | Acceptance Condition |
|---|---|
| Migration Job | One successful completion |
| Backend Deployment | All desired replicas Ready |
| Gateway Deployment | All desired replicas Ready |
| Worker Deployment | All desired replicas Ready |
| Reporter Deployment | All desired replicas Ready |
| Metrics Deployment | All desired replicas Ready |
| Pod stability | No Pods in CrashLoopBackOff |
| Reporter RBAC | Reporter ServiceAccount can list Pods |
| Backend health | Backend responds on `/healthz` |
| Gateway behavior | `/status` reports backend as healthy |
| Reporter behavior | `/report` returns a non-zero Pod count |

The scenario performs application-level checks from inside the Kubernetes environment.

This is important because successful Pod readiness alone does not prove that the application components can communicate correctly.

**Final assessment result:** Successful completion of the Part 4 troubleshooting exercise and verification was reported, with an `ALL GREEN` result.

The exact final terminal transcript should be retained in the repository as supporting evidence.

## 8. Session Recording and Findings Documentation

The assessment requires documentation of the troubleshooting process and the reasoning behind each correction.

### 8.1 Record the Troubleshooting Session

Start a terminal recording:

```bash
script -q part4-session.log
```

Perform the troubleshooting and verification operations.

Exit the recording shell:

```bash
exit
```

The resulting file contains the captured terminal session.

### 8.2 Findings Document

File:

```text
lab/FINDINGS.md
```

Each issue should be documented using the following structure:

**1. Symptom**

Describe the observed failure and include the relevant terminal output.

**2. Root Cause**

Explain the underlying Kubernetes configuration or application issue.

**3. Fix**

Document the exact Helm template or values correction.

**4. How I Found It**

Include the diagnostic commands and explain how the investigation identified the problem.

A useful findings entry should explain not only what was changed but also why the original configuration failed.

### 8.3 Expected Deliverables

```text
lab/
├── FINDINGS.md
├── part4-session.log
├── scenario.sh
├── cluster-state/
│   ├── namespace.yaml
│   └── limits.yaml
└── broken-chart/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── backend.yaml
        ├── gateway.yaml
        ├── metrics.yaml
        ├── migrate-job.yaml
        ├── rbac.yaml
        ├── reporter.yaml
        └── worker.yaml
```

## 9. Part 4 Completion Checklist

- [x] Inspected the supplied troubleshooting scenario.
- [x] Reviewed the broken Helm chart and templates.
- [x] Investigated workload configuration.
- [x] Investigated container security requirements.
- [x] Investigated resource constraints.
- [x] Investigated ServiceAccount and RBAC configuration.
- [x] Reviewed Service selectors and application connectivity.
- [x] Applied targeted Helm chart corrections.
- [x] Reported successful completion of the final scenario verification.
- [ ] Confirm all six root causes and exact corrections are documented in `lab/FINDINGS.md`.
- [ ] Confirm the final `ALL GREEN` output is captured in the session recording.
- [ ] Confirm `part4-session.log` is present in the repository.

The final three items are repository evidence checks, not claims that the troubleshooting exercise itself remains incomplete.

## 10. Conclusion

Part 4 demonstrates a structured, evidence-driven approach to Kubernetes troubleshooting.

The exercise involved investigating intentionally misconfigured workloads, identifying the underlying causes, applying targeted Helm chart corrections, redeploying the affected resources, and validating the environment against the supplied acceptance tests.

The troubleshooting covered six important areas:

1. Kubernetes Job lifecycle and restart policies.
2. Container security contexts and non-root image execution.
3. Resource requests, limits, and namespace constraints.
4. ServiceAccount permissions and RBAC bindings.
5. Service selectors, endpoint discovery, and application networking.
6. Helm template consistency and workload configuration.

The key principle was to correct the underlying configuration problems without modifying the supplied assessment environment, unnecessarily changing application images, disabling security controls, or bypassing the acceptance tests.

The reported `ALL GREEN` result provides the final functional verification milestone. Preserving the exact terminal transcript and documenting the six root causes in `FINDINGS.md` completes the assessment evidence.

---

# Final Assessment Summary

## 1. Overall Implementation

| Part | Main Deliverable | Key Outcome |
|---|---|---|
| Part 1 | Flask application and Docker image | Containerized application with health endpoint and non-root execution |
| Part 2 | Reusable Helm chart | Kubernetes deployment with configurable resources and networking |
| Part 3 | Root-level `setup.sh` | Repeatable Kind environment and Helm deployment workflow |
| Part 4 | Corrected troubleshooting Helm chart | Successful reported acceptance verification |

## 2. Technology Stack

| Category | Technologies |
|---|---|
| Application | Python, Flask |
| Application Server | Gunicorn |
| Containerization | Docker, Multi-stage Builds |
| Container Security | Non-root User, UID/GID 10001 |
| Orchestration | Kubernetes |
| Local Cluster | Kind |
| Package Management | Helm |
| Networking | ClusterIP, NGINX Ingress, Gateway API |
| Configuration | ConfigMaps, Environment Variables |
| Scaling | Horizontal Pod Autoscaler |
| Security | Kubernetes Security Contexts, ServiceAccounts, RBAC |
| Automation | Bash, Shell Scripting |
| Validation | curl, Helm lint, kubectl, scenario.sh |

## 3. Important Validation Commands

The following commands provide a consolidated reference for validating the complete assessment.

### Docker

```bash
docker build -t eb-demo-service:1.0 ./service

docker images

docker image inspect eb-demo-service:1.0
```

### Helm

```bash
helm lint ./chart

helm template demo ./chart

helm list -n demo

helm status demo -n demo
```

### Kubernetes

```bash
kubectl config current-context

kubectl get nodes

kubectl get all -n demo

kubectl get pods -n demo -o wide

kubectl get events -n demo \
  --sort-by=.metadata.creationTimestamp
```

### Automation

```bash
bash -n setup.sh

./setup.sh
```

### Troubleshooting

```bash
cd ~/eb-devops-assessment/lab

./scenario.sh up

./scenario.sh verify
```

### Final Repository Check

```bash
cd ~/eb-devops-assessment

git status --short

find . -maxdepth 4 -type f \
  ! -path './.git/*' \
  | sort
```
Part 5 – ANSWERS.md

Question: You have 40 Kubernetes Ingress objects. How would you migrate them to Gateway API?

### Answer – Migrating 40 Ingress Objects to Gateway API

I would migrate the 40 Ingress objects gradually rather than changing everything at once.

First, I would review all existing Ingress resources and understand their hosts, paths, TLS settings, annotations, backend services, and any controller-specific configurations. Then I would map these configurations to Gateway API resources such as `GatewayClass`, `Gateway`, and `HTTPRoute`.

Next, I would install a Gateway API-compatible controller and create a shared Gateway with the required listeners, certificates, and routing configuration. I would migrate a few low-risk applications first by creating their corresponding HTTPRoutes.

I would validate DNS resolution, TLS, path-based routing, backend connectivity, health checks, and application behavior. I would also compare logs, metrics, and error rates with the existing Ingress setup.

Once the initial applications work correctly, I would migrate the remaining routes in batches. During the migration, I would keep the existing Ingress resources available as a rollback option.

After all applications are verified, I would update DNS or traffic routing as needed, monitor the environment, and remove the old Ingress resources only after confirming that everything is stable.

# Enterprise Bot – DevOps Assessment

## 1. Project Overview

This repository contains the implementation of a containerized Python HTTP service, a Helm chart for Kubernetes deployment, an automated local Kubernetes setup script, and a debugging exercise involving an intentionally broken Helm chart.

The assessment is organized into the following parts:

| Part | Description | Location |
|---|---|---|
| 1 | Application development and Docker containerization | `service/` |
| 2 | Kubernetes deployment using Helm | `chart/` |
| 3 | Local Kubernetes environment automation | `setup.sh` |
| 4 | Kubernetes debugging and troubleshooting | `lab/` |
| 5 | Technical questions and answers | `ANSWERS.md` |
| 6 | Project documentation | `README.md` |

## 2. Prerequisites

Install the following tools before running the project:

- Docker
- kubectl
- Kind
- Helm 3
- Bash
- curl
- Python 3 (for optional JSON response formatting)

Check the installed versions:

```bash
docker --version
kubectl version --client
kind version
helm version
bash --version
python3 --version
```

Ensure Docker is running and the current user has permission to access the Docker daemon.

## 3. Repository Structure

```text
.
├── README.md
├── README-assignment-reference.md
├── ANSWERS.md
├── setup.sh
├── service/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── configmap.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── httproute.yaml
│       ├── serviceaccount.yaml
│       ├── hpa.yaml
│       └── tests/
│           └── test-connection.yaml
├── k8s/
│   └── helm/
│       └── python-service/
└── lab/
    ├── FINDINGS.md
    ├── scenario.sh
    ├── cluster-state/
    ├── broken-chart/
    └── part-4-session.log
```

The `chart/` directory is the main Helm chart used by the root-level deployment workflow. The additional chart under `k8s/helm/python-service/` is retained as a separate copy until its contents and purpose are confirmed.

## 4. Part 1 – Application and Docker

### Application functionality

The Flask application exposes two HTTP endpoints:

- `GET /` – Returns the application name, version, and container or pod hostname.
- `GET /healthz` – Returns the application health status.

The application supports configuration through environment variables such as `APP_NAME` and `VERSION`.

### Build the Docker image

Run from the repository root:

```bash
docker build -t eb-demo-service:v1.0 ./service
```

### Start the container

```bash
docker run -d \
  --name eb-demo-test \
  -p 8080:8080 \
  -e APP_NAME=assessment-service \
  -e VERSION=1.0.0 \
  eb-demo-service:v1.0
```

### Validate the endpoints

```bash
curl -i http://localhost:8080/
curl -i http://localhost:8080/healthz
```

### Verify the container user

```bash
docker exec eb-demo-test id

docker image inspect eb-demo-service:v1.0 \
  --format='{{.Config.User}}'
```

### Results recorded during the assessment

- The `/healthz` endpoint returned HTTP 200.
- The health response was `{"status":"healthy"}`.
- The container ran as UID `10001` and GID `10001`.
- The image configuration reported user `10001:10001`.
- The container used for validation was `eb-demo-test`.
- The local image was `eb-demo-service:v1.0`.

**Validation note:** The non-root and health checks passed. An additional runtime assertion expecting the root endpoint to return `app=assessment-service` failed. The root response and environment configuration should be checked before claiming that this assertion passed.

Useful troubleshooting commands:

```bash
docker ps -a
docker logs eb-demo-test
docker inspect eb-demo-test
docker exec eb-demo-test env
```

## 5. Part 2 – Helm Deployment

The Helm chart packages the application Kubernetes resources into a reusable deployment.

The chart includes:

- Deployment
- Service
- ConfigMap
- ServiceAccount
- Ingress
- HTTPRoute
- HorizontalPodAutoscaler
- Helm connection test

### Validate the chart

```bash
helm lint ./chart
```

### Recorded result

```text
==> Linting ./chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

The chart passed Helm linting. The icon message is informational.

### Render Kubernetes manifests

```bash
helm template demo ./chart \
  --set replicaCount=3 \
  --set config.appName=assessment-service \
  --set config.version=2.5.0 \
  --set ingress.host=demo.local
```

This command renders the Kubernetes resources locally without installing them.

### Install or upgrade the release

```bash
kubectl create namespace demo \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install demo ./chart \
  --namespace demo
```

### Verify deployment resources

```bash
helm list -n demo

kubectl get deployments -n demo
kubectl get pods -n demo -o wide
kubectl get services -n demo
kubectl get ingress -n demo
kubectl get configmaps -n demo
kubectl get serviceaccounts -n demo
kubectl get hpa -n demo
```

### Recorded deployment information

A recorded Helm release showed:

```text
NAME: demo
NAMESPACE: demo
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
```

The recorded deployment snapshot also showed:

- Deployment: `demo-enterprise-demo`
- Two application pods reported ready and running.
- Service: `demo-enterprise-demo`
- Ingress host: `demo.local`
- ServiceAccount: `demo-enterprise-demo`
- ConfigMap: `demo-config`

The Ingress controller was also



## 4. Final Conclusion

This four-part assessment demonstrates an end-to-end DevOps workflow, starting with application development and containerization, followed by Kubernetes deployment, environment automation, and production-oriented troubleshooting practices.

The implementation establishes a foundation for understanding how applications are packaged, deployed, configured, exposed, monitored, and debugged in a Kubernetes environment.

The assessment also emphasizes several important engineering practices:

- Build reproducible container images.
- Run application containers with least privilege.
- Manage Kubernetes resources through reusable Helm charts.
- Separate application configuration from container images.
- Automate repetitive deployment operations.
- Design scripts to reuse existing infrastructure safely.
- Diagnose failures through logs, events, resource inspection, and RBAC checks.
- Validate application behavior using actual HTTP and in-cluster connectivity tests.
- Preserve terminal evidence and document root cause analysis.

**Final assessment objective:** Demonstrate the ability to develop, containerize, deploy, automate, troubleshoot, and validate an application using practical DevOps and Kubernetes engineering techniques.

