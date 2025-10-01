# OpenTofu Infrastructure Setup

This repository contains Infrastructure-as-Code (IaC) definitions for provisioning and managing AWS resources using [OpenTofu](https://opentofu.org).  
The goal is to establish a reusable, modular foundation for IAM roles, security policies, S3/Iceberg data lake, EKS clusters, and related services.

---

## Features
- **IAM & Security Policies**
  - Developer IAM roles with least-privilege
  - GitHub OIDC integration for CI/CD