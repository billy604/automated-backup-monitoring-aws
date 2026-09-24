# Incident Runbook — Automated Backup & Monitoring System

This document explains what each alarm means, what to check when it fires, and how to manually recover from common failure scenarios.

## Alarms and Response Steps

### `backup-lambda-errors`
**What it means:** The nightly EBS backup Lambda threw an unhandled exception during execution.

**Immediate steps:**
1. Go to CloudWatch → Log groups → `/aws/lambda/automated-ebs-backup` and check the most recent log stream for the stack trace.
2. Common causes: an EC2 volume tagged `Backup=true` was deleted mid-run, an IAM permission was removed, or a transient AWS API throttling error.
3. If it's a transient error, no action needed — the next scheduled run will likely succeed on its own.
4. If it's a permissions issue, check `iam.tf` — the `lambda_backup_policy` resource — to confirm the function still has `ec2:CreateSnapshot` and `ec2:CreateTags`.

### `cleanup-lambda-errors`
**What it means:** The retention/cleanup Lambda failed while trying to delete old snapshots.

**Immediate steps:**
1. Same log group pattern: CloudWatch → Log groups → `/aws/lambda/automated-ebs-cleanup`.
2. A common cause: attempting to delete a snapshot that's currently being used to create a new volume elsewhere — AWS blocks deletion in that case. This is expected and self-resolving; the snapshot will be eligible again once that operation finishes.

### `rds-high-connection-count`
**What it means:** The three-tier application's RDS database has had more than 50 average open connections for 10+ consecutive minutes.

**Immediate steps:**
1. Check the app tier's Auto Scaling Group — is it under unusually high load (many instances, high CPU)? If so, this may just be legitimate traffic.
2. If traffic looks normal, check application code for a possible connection leak (connections opened but never closed).
3. As a short-term mitigation, restarting app-tier instances (one at a time, to preserve availability) will forcibly close their open database connections.

### `app-tier-high-cpu`
**What it means:** Average CPU across the app tier's Auto Scaling Group has exceeded 80% for 10+ consecutive minutes.

**Immediate steps:**
1. Check whether this correlates with a real traffic spike (expected, and the ASG should already be scaling out to compensate).
2. If CPU is high but traffic is normal, investigate for a runaway process or inefficient code path on the app servers via Session Manager.

## Manual Snapshot Restore

To restore a volume from a snapshot created by this system:
1. Go to EC2 → Snapshots, locate the snapshot by its `SourceVolume` tag (matches the original volume it was backed up from).
2. Select it → Actions → Create volume from snapshot, choosing the same Availability Zone as wherever it needs to be attached.
3. Attach the new volume to the target EC2 instance.

## Deliberately Testing Alerts

To verify the alerting pipeline end-to-end without waiting for a real failure:
1. Temporarily introduce a `raise Exception(...)` at the top of `backup_handler.py`.
2. Run `terraform apply` to redeploy the broken version.
3. Invoke the function 1-2 times via `aws lambda invoke`.
4. Wait up to 5-10 minutes for the CloudWatch alarm to evaluate and fire.
5. **Revert the change and redeploy immediately after confirming the alert** — do not leave the deliberately broken version live.