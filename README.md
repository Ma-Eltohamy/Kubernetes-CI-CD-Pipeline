![overview image](./arch.png)

# 📄 Project Overview

This project automates the deployment process of a web application using a CI/CD pipeline built with GitHub Webhooks, Jenkins, Ansible, Docker, and Kubernetes. The goal is to simulate a complete deployment workflow without relying on cloud services like AWS, using Docker containers to replicate a real-world environment.

Here’s how the flow works:

**Developer Interaction:** A developer pushes code or performs actions (e.g., commits, merges) to a GitHub repository.

**GitHub Webhook Trigger:** The repository is configured with a GitHub Webhook. A webhook is a lightweight notification mechanism that sends an HTTP POST request to a predefined URL when specified events occur (e.g., push, pull_request). Unlike GitHub Actions, which run workflows directly in GitHub, webhooks only notify external services like Jenkins to perform actions.

**Jenkins CI:** Jenkins receives the webhook notification and triggers a pipeline job. Jenkins then clones the repository onto its workspace.

**File Transfer to Ansible Server:** Jenkins copies the cloned repository to a separate Ansible server. This server is responsible for image creation and deployment logic.

**Docker Build & Push:** The Ansible server uses Docker to build, tag, and push the application image to a container registry. Docker must be installed and configured on this server.

**Deployment to Kubernetes:** The Ansible server copies the necessary deployment files to the Kubernetes cluster server. Then, using kubectl, it applies the manifests to deploy the application.

**Web Access:** Once deployed, the application is exposed and can be accessed through a web browser via a Kubernetes service (e.g., LoadBalancer or NodePort).

Due to AWS Free Tier limitations, this project avoids using AWS services and instead relies entirely on Docker containers to simulate the servers and environment.
