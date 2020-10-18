param(
    [string]
    $s3BucketName,

    [string]
    $version,
    
    [string]
    $notificationTopic
)

#todo: check bucket exists and accessible

$codeZipFileName = "code.zip"
$dependenciesZipFileName = "dependencies.zip"

Write-Host "Zipping code and dependencies"

7z a $codeZipFileName .\src\scripts\* | Out-Null
7z a $dependenciesZipFileName .\src\dependencies\* | Out-Null

Write-Host "Finished zipping code and dependencies"

Write-Host "Uploading files to s3"

aws s3 cp $codeZipFileName "s3://$($s3BucketName)/v$($version)/$($codeZipFileName)"
aws s3 cp $dependenciesZipFileName "s3://$($s3BucketName)/v$($version)/$($dependenciesZipFileName)"

Write-Host "Finished uploading files to s3"

Write-Host "Remove zip files"

Remove-Item $codeZipFileName
Remove-Item $dependenciesZipFileName

Write-Host "Finished remove zip files"

terraform apply -var="bucket=$($s3BucketName)" -var="app_version=$($version)" -var="notification_topic=$($notificationTopic)"