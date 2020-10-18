# CloudWatch Log Group Checker

Makes sure that all the CloudWatch log groups have a retention policy.

## Required Tools

* Terraform
  * Uses the AWS provider so credentials are required.
* PowerShell
  * Runs the deployment script

## How the system works

1. In the deployments folder is a script `deployToAws.ps1`, it takes the parameters `s3BucketName`, `version`, `notificationTopic`.
1. The script will zip up the scripts in `src\scripts\` and the dependencies in `src\dependencies`. These are the files that run inside the lambda.
1. Then terraform runs over the system and creates all the components in AWS.
1. When the lambda is ran, it collects all the log groups in the region and does a check to make sure they all have a retention policy.
1. If any of the groups don't have a retention policy it will then update the group to give it the default retention policy.
