# Automated Backup & Monitoring System

[![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20EventBridge%20%7C%20CloudWatch%20%7C%20SNS-orange)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-boto3-blue)](https://boto3.amazonaws.com/)

> **Project 3 of 7 — Beginner tier.**
> This is the project where I stopped building things that just *sit there* and started building something that *acts on its own*. [See the full series →](#the-rest-of-the-series)

## What this is

Two small Lambda functions and a handful of CloudWatch alarms that, together, do two jobs: back up tagged EBS volumes every night and clean up old snapshots on a retention schedule, and separately, watch for problems and actually email me the moment something breaks — instead of sitting in a dashboard nobody's looking at.

I like this project because none of it requires a server running 24/7. It only exists, and only costs anything, for the few seconds it's actually doing work.

## Why it's built this way

The backup function only touches EBS volumes tagged `Backup = true`, not every volume in the account. I did that on purpose — a blanket "back up everything" policy sounds safer but actually isn't, because it means you never really know what's being backed up or why. Opt-in tagging keeps that decision explicit.

The cleanup function reads its retention window from an environment variable instead of a hardcoded number, so I can change "keep backups for 7 days" to "keep them for 30" by changing one line in Terraform — no code change, no redeploy of logic, just configuration.

## How it fits together

```
EventBridge (2:00 AM) ──► backup Lambda   ──► tags + creates EBS snapshots
EventBridge (2:30 AM) ──► cleanup Lambda  ──► deletes snapshots past retention

CloudWatch Alarms (Lambda errors, RDS connections, app-tier CPU)
        │ threshold breached
        ▼
   SNS Topic ──► email
```

Cleanup deliberately runs 30 minutes after backup, not at the same time — I wanted that night's fresh backup to be fully tagged and complete before the cleanup job goes looking for anything to delete, rather than risking a race between the two.

## Repo layout

```
automated-backup-monitoring-aws/
├── lambda/
│   ├── backup_handler.py
│   └── cleanup_handler.py
├── iam.tf                → the Lambda execution role and its permissions
├── lambda.tf              → packaging + deploying both functions
├── eventbridge.tf          → the nightly schedule
├── sns.tf                  → the alert topic and my email subscription
├── monitoring.tf            → all four CloudWatch alarms
└── docs/
    └── runbook.md            → what to actually do when an alarm fires
```

## Running it yourself

```bash
terraform init
terraform apply
```

After `apply`, check your email (and your spam folder — SNS confirmation emails end up there constantly) and click the subscription confirmation link. Alerts genuinely will not reach you until you do.

## Proof this actually works — not just "it deployed"

I didn't want to just trust that the alerting chain worked; I deliberately broke it to find out. I added a `raise Exception(...)` to the backup function, redeployed it, invoked it a couple of times to generate real errors, and watched the CloudWatch alarm flip from `INSUFFICIENT_DATA` to `ALARM` and a real email land in my inbox a few minutes later — full alarm details, threshold, timestamp, everything. Then I reverted the bug and redeployed the working version immediately, because leaving a deliberately broken backup function running would defeat the entire point of the project.

That test also caught a real mistake on my part: two of the four alarm blocks had gone missing from `monitoring.tf` at some point (best guess — an earlier file edit overwrote more than I meant it to), and Terraform's own `plan` output was what actually surfaced it — "no changes needed" when I expected new alarms was the tell that something was declared missing, not something that had failed to create. That whole debugging thread ended up directly in [`docs/runbook.md`](docs/runbook.md), because it's a genuinely useful thing to know if it happens again.

## What I'd do differently in a real production setup

| What I simplified | What a production team would do instead |
|---|---|
| `Resource = "*"` on the Lambda's EC2 permissions | Scope this down with IAM condition keys, so the function can only touch resources carrying the right tags |
| No automated policy scanning | Checkov or tfsec on every PR, catching over-broad IAM policies like the one above automatically |
| No infrastructure tests | Terratest validating the deployed alarms and Lambda functions actually behave as expected |
| Deletion in `cleanup_handler.py` is immediate and permanent | A "pending deletion" grace period, or requiring manual approval past a certain retention threshold |
| Terraform state stored locally on my laptop | Remote state with locking, so this could safely be run by more than just me |

(Project 6 is where I actually go back and fix the state, testing, and policy-scanning items properly — this table doubles as a preview of that.)

## Skills this one actually taught me

Lambda + EventBridge for scheduled serverless automation, IAM execution roles (and specifically, remembering that logging permissions aren't automatic — I'd have had zero visibility into failures without them), CloudWatch alarms and SNS notifications, and a fair amount of real operational debugging: an AWS CLI region mismatch that had nothing to do with my Terraform code, and learning to trust `terraform plan`'s verdict over my own memory of what I thought I'd written.

## The rest of the series

| # | Project | Tier |
|---|---|---|
| 1 | [Static Website + CDN](../static-site-cdn-aws) | Beginner |
| 2 | [Three-Tier VPC App](../three-tier-vpc-architecture-aws) | Beginner |
| 3 | **Automated Backup & Monitoring** (this one) | Beginner |
| 4 | Serverless REST API + CI/CD | Intermediate |
| 5 | Event-Driven Data Pipeline | Intermediate |
| 6 | Multi-Environment IaC Platform | Pro |
| 7 | Microservices on Kubernetes | Pro |