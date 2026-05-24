# 08. AWS Security Group as code (LocalStack + OpenTofu)

**English** | [日本語](README.ja.md)

The cloud-native take on microsegmentation: declare VPC, subnets, security groups in IaC and let the cloud platform enforce them. This lab runs the AWS API surface entirely offline via LocalStack, so you can iterate the Terraform model without an AWS bill.

## What this lab is, and isn't

LocalStack emulates the **AWS API** for EC2/VPC/SG. You can `terraform apply` real-looking resources, query SG memberships, and see rule wiring. According to LocalStack's docs, SG ingress rules are applied to its dockerised mock EC2 instances **at creation time only** (subsequent SG rule changes don't reach the running container). So treat this lab as "IaC + API exercise", not as packet-level enforcement proof.

For the actual packet-level verification of the same pattern, run Pattern 01 (K8s NetworkPolicy) and re-read the SG rules as the cluster equivalent.

## What gets verified

OpenTofu (the open-source Terraform fork) creates:

- 1 VPC
- 2 subnets (`web`, `app`)
- 3 security groups (`web-sg`, `app-sg`, `db-sg`) wired so that
  - web-sg accepts `:80` from `0.0.0.0/0`
  - app-sg accepts `:8080` from web-sg
  - db-sg accepts `:5432` from app-sg only

The script then runs `aws ec2 describe-security-groups --endpoint-url ...` and asserts the rule graph matches.

This is what an enterprise platform team would version-control. SG-as-code is what scales microsegmentation across hundreds of AWS accounts.

## Run

```bash
./run.sh
```

## Cleanup

```bash
./cleanup.sh
```
