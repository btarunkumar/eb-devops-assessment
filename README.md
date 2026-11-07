# DevOps Engineering Assessment

A containerized Python application deployed on Kubernetes using Docker, Helm, and Kind, with an automated setup workflow and a Kubernetes troubleshooting exercise.

## Project Overview

This repository contains my implementation of a multi-part DevOps engineering assessment. It demonstrates practical experience with application containerization, Kubernetes deployment, Helm chart development, deployment automation, and troubleshooting Kubernetes workloads.

The project is organized into four main areas:

- **Application:** A lightweight Python Flask service with configurable application metadata and a health endpoint.
- **Containerization:** A multi-stage Docker build with a non-root runtime user.
- **Kubernetes deployment:** A configurable Helm chart that manages application resources and exposes the service through NGINX Ingress.
- **Troubleshooting:** A separate Kubernetes debugging exercise involving workload scheduling, security contexts, RBAC, and other cluster-level configurations.

The application is deployed locally using a Kind Kubernetes cluster.

## Architecture

```text
                   Developer
                       |
                       |
                 Docker Build
                       |
                       v
              eb-demo-service:1.0
                       |
                       v
                 Kind Cluster
                       |
                Namespace: demo
                       |
                       v
                NGINX Ingress
                       |
                  demo.local
                       |
                       v
                Kubernetes Service
                       |
                       v
                  Deployment
                  /        \
                 v          v
              Pod 1        Pod 2
                 \          /
                  \        /
                   Flask App
                    Port 8080
                       |
              +--------+---------+
              |                  |
              v                  v
             GET /           GET /healthz
           Application       Health Check
            Details             Status
```

### Technology Stack

| Category | Technologies |
|---|---|
| Application | Python, Flask |
| Containerization | Docker, Multi-stage Builds |
| Orchestration | Kubernetes, Kind |
| Package Management | Helm |
| Ingress | NGINX Ingress Controller |
| Automation | Bash, Shell Scripting |
| Validation | Helm Lint, Helm Template, kubectl |
| Version Control | Git, GitHub |

## Repository Structure

```text
eb-devops-assessment/
│
├── README.md
├── README-assignment-reference.md
├── setup.sh
│
├── service/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
│
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── .helmignore
│   └── templates/
│       ├── _helpers.tpl
│       ├── configmap.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── httproute.yaml
│       ├── hpa.yaml
│       ├── serviceaccount.yaml
│       └── tests/
│
└── lab/
    ├── FINDINGS.md
    ├── scenario.sh
    ├── broken-chart/
    └── cluster-state/
        ├── namespace.yaml
        └── limits.yaml
```

## Application Details

The application is a lightweight Flask service designed to demonstrate containerization and Kubernetes deployment.

### Available Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Returns application name, version, and pod hostname |
| `/healthz` | GET | Returns application health status |

Example application response:

```json
{
  "app": "enterprise-demo",
  "version": "1.0.0",
  "pod": "demo-application-pod"
}
```

Example health response:

```json
{
  "status": "healthy"
}
```

The application reads its configuration from `APP_NAME` and `VERSION`. The deployment also mounts ConfigMap configuration files under `/etc/app-config/`.

The container uses Gunicorn and runs as a non-root user.

## Prerequisites
<img width="1850" height="1170" alt="Screenshot from 2026-11-07 16-19-29" src="https://github.com/user-attachments/assets/8fdcc62d-0cc7-4062-be36-d4e765463c90" />

Ensure the following tools are installed:
- Aws ubuntu Compute instance
- Docker
- kubectl
- Kind
- Helm 3
- Git
- curl

Verify the installations:

```bash
docker --version
kubectl version --client
kind version
helm version
git --version
```

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/btarunkumar/eb-devops-assessment.git

cd eb-devops-assessment
```

### 2. Build the Docker image

```bash
docker build -t eb-demo-service:1.0 ./service
```

Verify the image:

```bash
docker images | grep eb-demo-service
```

1. Docker Image Build

<img width="1850" height="1170" alt="Screenshot from 2026-11-07 16-05-39" src="https://github.com/user-attachments/assets/7260a464-b1c2-4832-abe0-9d2f3f1088bb" />


### 3. Create or configure the Kind cluster

The repository includes an automated setup script.

```bash
chmod +x setup.sh

./setup.sh
```

The setup script is designed to:

- Create or reuse the Kind cluster named `demo`.
- Configure the Kubernetes context.
- Install or reuse the NGINX Ingress Controller.
- Build and load the application image into Kind.
- Install or upgrade the Helm release in the `demo` namespace.

The script is intended to be idempotent so that repeated executions do not unnecessarily recreate existing resources.

### 4. Verify the Kubernetes deployment

Check the active context:

```bash
kubectl config current-context
```

Check cluster nodes:

```bash
kubectl get nodes
```

Check namespace:

```bash
kubectl get namespace demo
```

Check application resources:

```bash
kubectl get all -n demo
```

Check Helm release:

```bash
helm list -n demo
```

Check Ingress:

```bash
kubectl get ingress -n demo
```
<img width="1850" height="1170" alt="Screenshot from 2026-11-07 16-04-59" src="https://github.com/user-attachments/assets/f1af1f33-989c-411e-85be-8ccab5cf4edc" />


### 5. Access the application

The configured Ingress hostname is:

```text
demo.local
```

For local access, configure `demo.local` to resolve to the Kind ingress endpoint on your machine.

<img width="1850" height="1170" alt="Screenshot from 2026-11-07 16-28-02" src="https://github.com/user-attachments/assets/2211e2ad-2fa7-411f-8bb2-97ff589e9c78" />


Alternatively, use port forwarding:

```bash
kubectl port-forward -n demo \
  svc/demo-enterprise-demo 8082:80
```

Open another terminal and test the application:

```bash
curl http://localhost:8082/
```

Check application health:

```bash
curl http://localhost:8082/healthz
```

## Helm Configuration

The Helm chart is maintained separately under the repository-root `chart/` directory.

The chart provides configurable Kubernetes resources, including:

- Deployment
- Service
- ConfigMap
- Ingress
- Horizontal Pod Autoscaler
- ServiceAccount

The default application configuration includes:

| Parameter | Default |
|---|---|
| Replica count | 2 |
| Application container port | 8080 |
| Kubernetes Service port | 80 |
| Application health endpoint | `/healthz` |
| Ingress hostname | `demo.local` |

Configuration can be customized through `values.yaml` or Helm command-line overrides.

Example:

```bash
helm upgrade --install demo ./chart \
  --namespace demo \
  --create-namespace \
  --set replicaCount=3 \
  --set config.appName=assessment-service \
  --set config.version=2.5.0 \
  --set ingress.host=demo.local
```

Validate the chart before deployment:

```bash
helm lint ./chart
```

Render the Kubernetes manifests:

```bash
helm template demo ./chart \
  --namespace demo
```

## Kubernetes Troubleshooting Exercise

The `lab/` directory contains a separate Kubernetes troubleshooting exercise.

It includes:

- A supplied cluster-state configuration.
- An intentionally broken Helm chart.
- A scenario execution script.
- Investigation findings and troubleshooting evidence.

The exercise focuses on identifying and resolving Kubernetes workload failures by examining:

- Pod status and container startup failures.
- Kubernetes events and scheduling constraints.
- Security contexts and non-root execution.
- Resource requests and limits.
- RBAC permissions.
- Service and workload configuration.

The findings and remediation details are documented in:

```text
lab/FINDINGS.md
```

The original scenario and supplied cluster-state files are retained as assessment inputs.

## Troubleshooting Commands

Useful commands for investigating Kubernetes workloads:

```bash
# List pods
kubectl get pods -A

# Inspect pod details
kubectl describe pod <pod-name> -n <namespace>

# Inspect namespace events
kubectl get events -n <namespace> \
  --sort-by=.metadata.creationTimestamp

# Inspect pod logs
kubectl logs <pod-name> -n <namespace>

# Check deployments
kubectl get deployments -n <namespace>

# Check services
kubectl get services -n <namespace>

# Check Helm release
helm list -A

# Inspect rendered Helm resources
helm get manifest demo -n demo
```

## Cleanup

Remove the Helm release:

```bash
helm uninstall demo -n demo
```

Delete the Kind cluster when the assessment environment is no longer required:

```bash
kind delete cluster --name demo
```

## Engineering Practices Demonstrated

This assessment demonstrates practical implementation of:

- Containerizing a Python application.
- Building a smaller, multi-stage Docker image.
- Running containers with non-root privileges.
- Managing Kubernetes resources through Helm.
- Externalizing application configuration.
- Implementing readiness and liveness health checks.
- Configuring Kubernetes resource requests and limits.
- Automating local Kubernetes deployments.
- Troubleshooting scheduling, security, and RBAC failures.
- Validating infrastructure configurations before deployment.

## Author

**Tarun Kumar**

DevOps Engineer | AWS | Docker | Kubernetes | Helm | Linux | CI/CD

GitHub: https://github.com/btarunkumar

LinkedIn: https://www.linkedin.com/in/btarunkumar/

---

This repository is maintained as a technical assessment and hands-on demonstration of DevOps engineering practices.
