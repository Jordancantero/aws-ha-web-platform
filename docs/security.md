# Security

## Overview

Security is a fundamental design principle of the **Production-Inspired Highly Available Cloud Platform on AWS**. The platform implements a defense-in-depth strategy by applying multiple layers of protection across networking, identity management, infrastructure, and application services.

The architecture follows AWS security best practices to reduce the attack surface, protect sensitive resources, and ensure secure communication between application components.

---

# Security Objectives

The security architecture was designed to achieve the following objectives:

- Protect internet-facing resources.
- Isolate sensitive workloads.
- Prevent unauthorized access.
- Secure application secrets.
- Enforce least-privilege access.
- Eliminate static credentials.
- Maintain secure administrative access.
- Enable centralized monitoring and auditing.

---

# Security Architecture

<p align="center">
    <img src="../aseets/architecture-diagram.png" width="100%">
</p>

The platform applies multiple independent security layers.

The security model includes:

- AWS WAF
- Security Groups
- Private Subnets
- IAM Roles
- AWS Secrets Manager
- AWS Systems Manager Session Manager
- VPC Endpoints
- Amazon CloudWatch

Each layer protects different parts of the infrastructure while minimizing the overall attack surface.

---

# Defense in Depth

The platform follows a Defense in Depth security model by implementing multiple security controls across the entire architecture.

```
Internet
    │
    ▼
AWS WAF
    │
    ▼
Application Load Balancer
    │
    ▼
Security Groups
    │
    ▼
Private Application Subnets
    │
    ▼
Amazon EC2
    │
    ▼
Amazon RDS
    │
    ▼
AWS Secrets Manager
    │
    ▼
CloudWatch Monitoring
```

If one security layer is compromised, additional controls continue protecting the infrastructure.

---

# Network Security

Sensitive resources are isolated inside private subnets.

Network protections include:

- Private Application Subnets
- Private Database Subnets
- No public IP addresses assigned to EC2 instances
- Security Group filtering
- Private communication using VPC Endpoints

Only the Application Load Balancer is exposed to the internet.

---

# Security Groups

Security Groups provide stateful network-level firewall protection.

The project uses dedicated Security Groups for each infrastructure layer.

## Application Load Balancer

### Inbound Rules

| Protocol | Port | Source |
|----------|-----:|--------|
| HTTP | 80 | Internet |
| HTTPS | 443 | Internet |

### Outbound Rules

| Protocol | Port | Destination |
|----------|-----:|-------------|
| HTTP | 5000 | Application Security Group |

---

## Application Servers

### Inbound Rules

| Protocol | Port | Source |
|----------|-----:|--------|
| HTTP | 5000 | ALB Security Group |

### Outbound Rules

| Protocol | Port | Destination |
|----------|-----:|-------------|
| PostgreSQL | 5432 | Database Security Group |
| HTTPS | 443 | Interface Endpoints |
| HTTPS | 443 | Amazon S3 Gateway Endpoint |

---

## Amazon RDS

### Inbound Rules

| Protocol | Port | Source |
|----------|-----:|--------|
| PostgreSQL | 5432 | Application Security Group |

No outbound rules are required because Security Groups are stateful.

---

## Interface Endpoints

### Inbound Rules

| Protocol | Port | Source |
|----------|-----:|--------|
| HTTPS | 443 | Application Security Group |

These rules ensure that AWS service communication remains private.

---

# Identity and Access Management (IAM)

AWS Identity and Access Management (IAM) controls access to AWS resources following the Principle of Least Privilege.

IAM is used to:

- Grant EC2 access to Amazon ECR.
- Retrieve secrets from AWS Secrets Manager.
- Publish logs to Amazon CloudWatch.
- Access Amazon S3.
- Communicate with AWS Systems Manager.

Permissions are granted only when required.

---

# IAM Roles

EC2 instances use IAM Roles instead of long-lived AWS Access Keys.

Benefits include:

- Temporary credentials.
- Automatic credential rotation.
- Reduced credential exposure.
- Improved security.

No AWS Access Keys are stored on EC2 instances.

---

# AWS Secrets Manager

Sensitive information is securely stored using AWS Secrets Manager.

Examples include:

- Database username
- Database password
- Application secrets

The application retrieves secrets dynamically at runtime using its IAM Role.

Secrets are never stored:

- In source code
- In Terraform files
- In Docker images
- In GitHub repositories

---

# AWS Systems Manager Session Manager

Administrative access is performed using AWS Systems Manager Session Manager.

Benefits include:

- No SSH access required
- No public IP addresses
- No SSH keys to manage
- IAM-based authentication
- Session logging support

This significantly reduces administrative attack vectors.

---

# VPC Endpoints

Application servers communicate with AWS services privately through VPC Endpoints.

Configured endpoints include:

- Amazon ECR API
- Amazon ECR Docker Registry
- AWS Secrets Manager
- Amazon CloudWatch Logs
- Amazon S3 Gateway Endpoint

Private connectivity reduces internet exposure while improving security.

---

# Database Security

Amazon RDS is deployed inside dedicated private database subnets.

Security measures include:

- Private subnets
- Restricted Security Groups
- No public endpoint
- Multi-AZ deployment
- Application-only connectivity

The database cannot be accessed directly from the internet.

---

# Application Security

Application-level protections include:

- Docker container isolation
- Secure secret retrieval
- Least-privilege IAM permissions
- Secure file storage using Amazon S3
- Traffic inspection through AWS WAF

These controls reduce application-level security risks.

---

# AWS WAF

AWS WAF provides Layer 7 protection for the Application Load Balancer.

The WAF helps protect against common web attacks including:

- SQL Injection (SQLi)
- Cross-Site Scripting (XSS)
- Malicious bots
- Common OWASP threats

All HTTP requests are inspected before reaching the application.

---

# Monitoring and Auditing

Security events are monitored using Amazon CloudWatch and Amazon SNS.

Monitoring capabilities include:

- CloudWatch Metrics
- CloudWatch Logs
- CloudWatch Alarms
- Email Notifications

These services improve operational visibility and support incident response.

---

# Encryption

Sensitive data is protected both in transit and at rest.

Current implementation includes:

- HTTPS communication between AWS managed services where applicable.
- Encryption of secrets in AWS Secrets Manager.
- Amazon RDS encryption using AWS managed keys.
- Amazon S3 Server-Side Encryption (SSE).

Future improvements include:

- AWS Certificate Manager (ACM)
- Customer Managed AWS KMS Keys
- End-to-end HTTPS using a custom domain

---

# Security Best Practices

The platform follows several AWS security best practices.

Implemented practices include:

- Principle of Least Privilege.
- Defense in Depth.
- Public and Private subnet separation.
- IAM Roles instead of Access Keys.
- Secrets Manager for credential management.
- Session Manager instead of SSH.
- Private AWS service connectivity using VPC Endpoints.
- Infrastructure as Code using Terraform.
- Layer 7 protection with AWS WAF.

These practices improve the confidentiality, integrity, and availability of the platform.

---

# Security Design Decisions

The following architectural decisions were made to strengthen the overall security posture of the platform.

| Decision | Reason |
|----------|--------|
| Private EC2 Instances | Prevent direct internet access to application servers. |
| Private RDS Deployment | Protect the database from external access. |
| Session Manager | Eliminate SSH exposure and key management. |
| IAM Roles | Avoid long-lived AWS credentials on EC2 instances. |
| AWS Secrets Manager | Securely store and retrieve application secrets at runtime. |
| VPC Endpoints | Keep AWS service communication within the AWS network instead of traversing the public internet. |
| Amazon S3 Gateway Endpoint | Enable private access to S3 while reducing NAT Gateway usage. |
| AWS WAF | Protect the application against common Layer 7 attacks before requests reach the application. |
| Security Groups | Restrict network communication using least-privilege access rules. |
| Multi-Layer Isolation | Separate internet, application, and database tiers to minimize lateral movement in case of compromise. |

These decisions collectively improve the platform's security, reduce operational risk, and align the architecture with AWS Well-Architected Framework security principles.

---

# Future Security Improvements

Potential future enhancements include:

- AWS Certificate Manager (ACM)
- Customer Managed AWS KMS Keys
- AWS Shield Advanced
- AWS GuardDuty
- AWS Security Hub
- AWS Config
- Amazon Inspector
- AWS IAM Identity Center
- AWS CloudTrail Organization Trails

---

# Related Documentation

Additional documentation is available in:

- [Architecture](architecture.md)
- [Networking](networking.md)
- [Troubleshooting](troubleshooting.md)