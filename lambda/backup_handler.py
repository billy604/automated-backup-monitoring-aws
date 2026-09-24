import boto3
import datetime


ec2 = boto3.client("ec2")

def lambda_handler(event, context):
    volumes = ec2.describe_volumes(
        Filters=[{"Name": "tag:Backup", "Values": ["true"]}]
    )

    snapshot_ids = []
    for volume in volumes["Volumes"]:
        volume_id = volume["VolumeId"]
        snapshot = ec2.create_snapshot(
            VolumeId=volume_id,
            Description=f"Automated backup of {volume_id} on {datetime.date.today()}"
        )
        ec2.create_tags(
            Resources=[snapshot["SnapshotId"]],
            Tags=[
                {"Key": "CreatedBy", "Value": "automated-backup-lambda"},
                {"Key": "SourceVolume", "Value": volume_id}
            ]
        )
        snapshot_ids.append(snapshot["SnapshotId"])

    return {
        "statusCode": 200,
        "snapshotsCreated": snapshot_ids
    }