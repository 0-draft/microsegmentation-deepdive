# 08. AWS Security Group as code (LocalStack + OpenTofu)

> 🇯🇵 [日本語](./README.ja.md) ・ 🇺🇸 English

The cloud-native take on microsegmentation: declare VPC, subnets, security groups in IaC and let the cloud platform enforce them. This lab runs the AWS API surface entirely offline via LocalStack, so you can iterate the Terraform model without an AWS bill.

## What this lab is, and isn't

LocalStack emulates the **AWS API** for EC2/VPC/SG. It returns sensible responses, lets you query SG memberships, and applies SG rules to its mock EC2 instances (which are themselves Docker containers under the hood). What it does **not** do is enforce SGs the same way real AWS does at the hypervisor level. Read it as "the IaC + API exercise", not "packet-level proof".

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

About 1 minute (LocalStack pull is the heavy bit). Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```
