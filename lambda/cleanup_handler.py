import boto3
import os
import datetime

ec2 = boto3.client("ec2")

RETENTION_DAYS = int(os.environ.get("RETENTION_DAYS", "7"))

def lambda_handler(event, context):
    snapshots = ec2.describe_snapshots(
        OwnerIds=["self"],
        Filters=[{"Name": "tag:CreatedBy", "Values": ["automated-backup-lambda"]}]
    )

    cutoff_date = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=RETENTION_DAYS)
    deleted_ids = []

    for snapshot in snapshots["Snapshots"]:
        if snapshot["StartTime"] < cutoff_date:
            ec2.delete_snapshot(SnapshotId=snapshot["SnapshotId"])
            deleted_ids.append(snapshot["SnapshotId"])

    return {
        "statusCode": 200,
        "snapshotsDeleted": deleted_ids,
        "retentionDays": RETENTION_DAYS
    }