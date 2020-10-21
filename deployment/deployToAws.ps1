param(
    [Parameter()]
    [string]
    $s3BucketName,

    [Parameter()]
    [string]
    $appVersion,    
    
    [Parameter()]
    [string]
    $notificationTopic = "",

    [Parameter()]
    [string]
    $cloudWatchAlarmTopic = "",

    [switch]
    $updateModules
)

$codeZipFileName = "code.zip"
$dependenciesZipFileName = "dependencies.zip"

$s3codeZipFileName = "v$($appVersion)/$($codeZipFileName)"
$s3dependenciesZipFileName = "v$($appVersion)/$($dependenciesZipFileName)"

#todo: check it files already exist in s3
$codeExistsInS3 = $false
$dependenciesExistsInS3 = $false

if (!$codeExistsInS3 -or !$dependenciesExistsInS3) {

    Write-Host "Zipping code and dependencies"

    7z a $codeZipFileName .\src\scripts\* | Out-Null
    7z a $dependenciesZipFileName .\src\dependencies\* | Out-Null

    Write-Host "Finished zipping code and dependencies"

    Write-Host "Uploading files to s3"

    aws s3 cp $codeZipFileName "s3://$($s3BucketName)/$($s3codeZipFileName)"
    aws s3 cp $dependenciesZipFileName "s3://$($s3BucketName)/$($s3dependenciesZipFileName)"

    Write-Host "Finished uploading files to s3"

    Write-Host "Remove zip files"

    Remove-Item $codeZipFileName
    Remove-Item $dependenciesZipFileName

    Write-Host "Finished remove zip files"
}

terraform init

if ($updateModules) {
    terraform get -update
}

terraform apply -var="bucket=$($s3BucketName)" -var="app_version=$($appVersion)" -var="notification_topic=$($notificationTopic)" -var="cloud_watch_alarm_topic=$($cloudWatchAlarmTopic)" -auto-approve