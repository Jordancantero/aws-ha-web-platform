# Troubleshooting Guide

## Overview

This document describes the most significant technical challenges encountered during the development of the **Production-Inspired Highly Available Cloud Platform on AWS**.

Rather than providing generic AWS troubleshooting steps, this guide documents real issues experienced while building the project, including their symptoms, root causes, investigation process, applied solutions, and lessons learned.

The objective is to demonstrate practical Cloud Engineering experience while providing a useful operational reference for future maintenance and continuous improvement.

---

# Purpose

This document serves as an engineering incident log that captures the most relevant implementation challenges encountered throughout the project.

Documenting these incidents provides several benefits:

- Records real-world implementation challenges.
- Documents root cause analysis.
- Explains engineering decisions.
- Provides repeatable solutions.
- Captures lessons learned for future projects.
- Demonstrates practical troubleshooting skills.

---

# Incident Workflow

Each incident follows a standardized engineering format.

```
Problem
      │
      ▼
Symptoms
      │
      ▼
Root Cause Analysis
      │
      ▼
Investigation
      │
      ▼
Resolution
      │
      ▼
Lessons Learned
```

This structure resembles the incident documentation commonly used by Cloud Operations, DevOps, and Site Reliability Engineering (SRE) teams.

---

# Incident Summary

| ID | Incident | Severity | Status |
|----|----------|----------|--------|
| TR-001 | AWS WAF Blocking File Uploads (HTTP 403) | High | ✅ Resolved |
| TR-002 | EC2 Launch Template Root Volume Size | Medium | ✅ Resolved |
| TR-003 | Terraform Variables in GitHub Actions | Medium | ✅ Resolved |
| TR-004 | Amazon ECR Authentication Failure | High | ✅ Resolved |
| TR-005 | Amazon RDS Connectivity | High | ✅ Resolved |
| TR-006 | Application Load Balancer Health Checks | High | ✅ Resolved |
| TR-007 | AWS Systems Manager Session Manager | Medium | ✅ Resolved |
| TR-008 | Flask Database Configuration | Medium | ✅ Resolved |

---

# TR-001 — AWS WAF Blocking File Uploads (HTTP 403)

**Severity:** High

**Affected Component:** AWS WAF

**Status:** Resolved

---

## Problem

After enabling AWS WAF, users were unable to upload files through the web application.

Every upload request returned **HTTP 403 Forbidden**, even though the application had previously worked correctly.

---

## Symptoms

- File uploads consistently failed.
- Browser returned **HTTP 403 Forbidden**.
- Flask application never received the request.
- Application logs contained no errors.
- Application Load Balancer health checks remained healthy.

---

## Root Cause

AWS WAF Managed Rules classified legitimate **multipart/form-data** requests as potentially malicious and blocked them before forwarding traffic to the Application Load Balancer.

The application itself was functioning correctly.

---

## Investigation

The investigation followed these steps:

1. Verified that the Flask application was running correctly.
2. Confirmed Docker containers were healthy.
3. Verified Application Load Balancer health checks.
4. Reviewed Security Group rules.
5. Inspected CloudWatch metrics.
6. Reviewed AWS WAF Managed Rule Groups.

After eliminating all other infrastructure components, the issue was isolated to AWS WAF.

---

## Resolution

The AWS WAF configuration was updated to allow legitimate multipart/form-data requests while preserving protection against malicious traffic.

After adjusting the managed rule behavior, file uploads completed successfully without affecting the remaining security controls.

---

## Lessons Learned

- Managed WAF rules should always be validated using real application traffic.
- Security services may require application-specific tuning.
- Reviewing WAF logs significantly reduces troubleshooting time.
- Security should never be disabled without first identifying the exact blocking rule.

---

# TR-002 — EC2 Launch Template Root Volume Size

**Severity:** Medium

**Affected Component:** EC2 Launch Template

**Status:** Resolved

---

## Problem

Terraform failed while creating the EC2 Launch Template.

---

## Symptoms

Terraform reported an error indicating that the configured root EBS volume was smaller than the minimum size required by the selected Amazon Machine Image (AMI).

The infrastructure deployment stopped before creating the Auto Scaling Group.

---

## Root Cause

The selected AMI snapshot required a larger root volume than the value configured inside the Launch Template.

AWS rejected the Launch Template because shrinking an existing snapshot volume is not supported.

---

## Investigation

The following components were reviewed:

- Launch Template configuration
- Terraform variables
- AMI Block Device Mapping
- EC2 documentation

The configured EBS volume size was compared with the snapshot metadata, revealing the mismatch.

---

## Resolution

The Launch Template configuration was updated with a larger root EBS volume before executing Terraform again.

After increasing the volume size, Terraform successfully created the Launch Template and the remaining infrastructure.

---

## Lessons Learned

- Always verify AMI storage requirements before creating Launch Templates.
- Terraform errors may originate from AWS resource validation rather than Terraform itself.
- Reviewing AWS service documentation can significantly reduce troubleshooting time.

---

# TR-003 — Terraform Variables in GitHub Actions

**Severity:** Medium

**Affected Component:** GitHub Actions

**Status:** Resolved

---

## Problem

Terraform execution failed inside the GitHub Actions workflow because required variables were unavailable.

---

## Symptoms

- Workflow execution failed.
- Terraform reported missing required variables.
- Infrastructure deployment never started.

---

## Root Cause

Terraform expected configuration through **TF_VAR_*** environment variables, but the required GitHub Secrets had not been mapped correctly inside the workflow.

---

## Investigation

The GitHub Actions workflow was reviewed step by step.

The following items were verified:

- Repository Secrets
- Workflow variables
- Terraform input variables
- Environment variable mapping

The missing TF_VAR_* mappings were identified.

---

## Resolution

The required GitHub Secrets were created and exported as Terraform environment variables inside the GitHub Actions workflow.

After updating the workflow configuration, Terraform executed successfully.

---

## Lessons Learned

- CI/CD pipelines depend heavily on proper secret management.
- Sensitive values should never be stored directly inside workflow files.
- Always validate environment variables before executing Terraform.
- Infrastructure automation is only as reliable as its configuration management.

---

# TR-004 — Amazon ECR Authentication Failure

**Severity:** High

**Affected Component:** Amazon Elastic Container Registry (ECR)

**Status:** Resolved

---

## Problem

EC2 instances launched successfully but were unable to download the application container image from Amazon ECR.

---

## Symptoms

- Docker pull failed.
- Containers never started.
- User Data script terminated during initialization.
- Application was unavailable.

---

## Root Cause

The EC2 IAM Role lacked the permissions required to authenticate with Amazon Elastic Container Registry.

Without the appropriate IAM policy, Docker could not retrieve authorization tokens.

---

## Investigation

The following components were reviewed:

- EC2 IAM Role
- IAM Policies
- CloudWatch Logs
- User Data execution logs
- Amazon ECR repository permissions

The missing IAM permissions were identified as the root cause.

---

## Resolution

The required Amazon ECR permissions were attached to the EC2 IAM Role.

After launching new EC2 instances, Docker successfully authenticated with Amazon ECR, downloaded the latest image, and started the application.

---

## Lessons Learned

- Amazon ECR authentication relies entirely on IAM permissions.
- IAM Roles eliminate the need for long-lived credentials.
- CloudWatch logs provide valuable insight during EC2 bootstrap failures.
- Always validate IAM permissions before troubleshooting application-level issues.

---

# TR-005 — Amazon RDS Connectivity

**Severity:** High

**Affected Component:** Amazon RDS

**Status:** Resolved

---

## Problem

The Flask application was unable to establish a connection to the PostgreSQL database hosted on Amazon RDS.

---

## Symptoms

- Database connection errors during application startup.
- Flask application failed to initialize.
- Database operations could not be completed.
- Application became unavailable.

---

## Root Cause

The Database Security Group did not allow inbound PostgreSQL traffic from the Application Security Group.

Although both resources were deployed inside the same VPC, network communication was explicitly denied.

---

## Investigation

The following components were verified:

- Database endpoint
- Database credentials
- Route Tables
- Private Subnets
- Security Groups
- Network ACLs
- RDS availability

After validating the network configuration, the missing Security Group rule was identified.

---

## Resolution

The Database Security Group was updated to allow TCP port **5432** from the Application Security Group.

Application connectivity was immediately restored without requiring any changes to the application code.

---

## Lessons Learned

- Security Groups should reference other Security Groups whenever possible instead of IP addresses.
- Connectivity issues should be investigated from the network layer upward.
- Proper network segmentation improves security while requiring careful rule validation.

---

# TR-006 — Application Load Balancer Health Checks

**Severity:** High

**Affected Component:** Application Load Balancer

**Status:** Resolved

---

## Problem

The Application Load Balancer continuously marked EC2 instances as unhealthy.

---

## Symptoms

- Target Group reported unhealthy instances.
- Application returned HTTP 503.
- Requests never reached the application.
- Auto Scaling repeatedly replaced instances.

---

## Root Cause

The configured Health Check endpoint did not match the application's actual listening endpoint.

As a result, the ALB interpreted healthy instances as unavailable.

---

## Investigation

The following components were reviewed:

- Target Group configuration
- Health Check path
- Health Check port
- Flask routes
- Security Groups
- EC2 application logs

The mismatch between the configured Health Check path and the application endpoint was identified.

---

## Resolution

The Target Group Health Check configuration was updated to match the application's dedicated health endpoint.

Once updated, the instances immediately transitioned to the **Healthy** state and traffic was restored.

---

## Lessons Learned

- Every production application should expose a lightweight health endpoint.
- Validate Health Checks immediately after deployment.
- A healthy EC2 instance does not necessarily mean the application itself is healthy.

---

# TR-007 — AWS Systems Manager Session Manager

**Severity:** Medium

**Affected Component:** AWS Systems Manager

**Status:** Resolved

---

## Problem

AWS Systems Manager Session Manager could not establish remote sessions with EC2 instances.

---

## Symptoms

- EC2 instances appeared online.
- Session Manager connections failed.
- Remote administration was unavailable.

---

## Root Cause

The EC2 IAM Role lacked the permissions required by AWS Systems Manager.

Without the appropriate managed policy, the Systems Manager Agent could not register correctly.

---

## Investigation

The following components were reviewed:

- IAM Role
- IAM Policies
- Systems Manager Agent
- VPC Endpoints
- EC2 Instance Profile

The missing Systems Manager managed policy was identified.

---

## Resolution

The required AWS managed policy was attached to the EC2 IAM Role.

After restarting the Systems Manager Agent, remote administration became fully operational.

---

## Lessons Learned

- Session Manager requires both IAM permissions and a properly functioning SSM Agent.
- Eliminating SSH significantly reduces infrastructure attack surface.
- IAM Roles simplify secure infrastructure administration.

---

# TR-008 — Flask Database Configuration

**Severity:** Medium

**Affected Component:** Flask Application

**Status:** Resolved

---

## Problem

The application failed during startup because database credentials were unavailable.

---

## Symptoms

- Flask startup failed.
- Database initialization errors occurred.
- Docker container repeatedly restarted.
- Application never became healthy.

---

## Root Cause

Database credentials were not being retrieved correctly during application initialization.

Initially, configuration management relied on static values instead of retrieving secrets dynamically.

---

## Investigation

The following components were reviewed:

- Flask configuration
- Docker environment variables
- AWS Secrets Manager
- IAM Role permissions
- Application startup logs

The startup sequence was updated to retrieve secrets dynamically.

---

## Resolution

Database credentials were loaded directly from AWS Secrets Manager using the EC2 IAM Role.

All hardcoded credentials were removed from the application source code.

---

## Lessons Learned

- Application secrets should never be hardcoded.
- Secrets Manager simplifies secure credential management.
- Dynamic secret retrieval improves both security and maintainability.

---

# Overall Lessons Learned

Developing this platform reinforced several important Cloud Engineering principles.

Key takeaways include:

- Build security into the architecture from the beginning.
- Design infrastructure following AWS Well-Architected Framework principles.
- Prefer IAM Roles over static credentials.
- Keep application workloads inside private subnets.
- Validate infrastructure before deployment.
- Monitor infrastructure continuously.
- Use Infrastructure as Code to ensure repeatable deployments.
- Investigate root causes instead of only fixing symptoms.
- Document engineering decisions throughout the development lifecycle.

These lessons significantly improved both the architecture and the operational maturity of the project.

---

# Engineering Takeaways

Building this platform provided hands-on experience with designing, deploying, securing, automating, and troubleshooting production-oriented cloud infrastructure.

The project reinforced practical knowledge in several areas:

### AWS Networking

- VPC Design
- Public and Private Subnets
- Route Tables
- Internet Gateway
- NAT Gateway
- VPC Endpoints
- Security Groups

### Compute

- Amazon EC2
- Auto Scaling Groups
- Launch Templates
- Application Load Balancer

### Containers

- Docker
- Amazon Elastic Container Registry (ECR)

### Infrastructure as Code

- Terraform
- Modular infrastructure
- Resource dependencies
- State management

### Security

- IAM Roles
- AWS WAF
- AWS Secrets Manager
- AWS Systems Manager Session Manager
- Defense in Depth

### Monitoring

- Amazon CloudWatch
- CloudWatch Alarms
- Amazon SNS

### CI/CD

- GitHub Actions
- Automated Terraform deployment
- Infrastructure validation
- Secure secret management

Beyond learning AWS services, the project demonstrated the importance of structured troubleshooting, incremental validation, and continuous improvement when building cloud-native infrastructure.

---

# Related Documentation

For additional technical details, refer to:

- [Architecture](architecture.md)
- [Networking](networking.md)
- [Security](security.md)