const AWSXRay = require('aws-xray-sdk');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));

async function getLogGroups(nextToken) {
    var client = new AWS.CloudWatchLogs({
        region: process.env.AWS_REGION
    });

    return new Promise((resolve, reject) => {
        var params = {
            limit: '5'
        };

        if (nextToken) {
            params.nextToken = nextToken;
        }
        client.describeLogGroups(params, function (err, data) {
            if (err) {
                reject(err);
            }
            else {
                console.log(data);
                resolve(data);
            }
        });
    });
}

async function getMaximumRetentionPolicy() {
    var client = new AWS.SSM({
        region: process.env.AWS_REGION
    });

    return new Promise((resolve, reject) => {
        var params = {
            Name: process.env.PARAMETER_NAME
        };

        client.getParameter(params, function (err, data) {
            if (err) {
                reject(err);
            }
            else {
                resolve(data.Parameter.Value);
            }
        });
    });
}

async function updateLogGroupsRetentionPolicy(logGroup, retentionInDays) {
    var client = new AWS.CloudWatchLogs({
        region: process.env.AWS_REGION
    });

    return new Promise((resolve, reject) => {
        var params = {
            logGroupName: logGroup,
            retentionInDays: retentionInDays
        };

        client.putRetentionPolicy(params, function (err, data) {
            if (err) {
                reject(err);
            }
            else {
                resolve(data);
            }
        });
    });
}

async function publishToSns(messages) {
    var client = new AWS.SNS({
        region: process.env.AWS_REGION
    });

    return new Promise((resolve, reject) => {


        if (!process.env.NOTIFICATION_TOPIC) {
            resolve();
            return;
        }

        if (messages.length == 0) {
            resolve();
            return;
        }

        let fullMessage = {
            "messages": messages
        };

        var params = {
            Message: JSON.stringify(fullMessage),
            Subject: "LogGroupChecker",
            TopicArn: process.env.NOTIFICATION_TOPIC
        };

        client.publish(params, function (err, data) {
            if (err) {
                reject(err);
            }
            else {
                resolve(data);
            }
        });
    });
}


exports.handler = async (event, context) => {
    let nextToken = "";
    let gotAllGroups = false;

    let logGroups = [];

    while (!gotAllGroups) {
        await getLogGroups(nextToken).then(data => {
            if (data.nextToken) {
                nextToken = data.nextToken;
            }
            else {
                gotAllGroups = true;
            }

            logGroups = logGroups.concat(data.logGroups);
        }
        ).catch(err => {
            console.error(err);
            throw err;
        });
    }

    if (logGroups.length == 0) {
        console.log("Unable to find any log groups.");
        return;
    }

    let maximumLogRetention = "3";
    let logGroupsNeedingUpdated = [];

    await getMaximumRetentionPolicy().then(data => {
        maximumLogRetention = data;
    }
    ).catch(err => {
        console.error(err);
        throw err;
    });

    let messages = [];

    logGroups.forEach(group => {
        if (!group.retentionInDays || group.retentionInDays > maximumLogRetention) {
            console.log(`${group.logGroupName} needs to have its retention policy updated. Current policy: ${group.retentionInDays ? `${group.retentionInDays} days` : "No expiry"}. New policy: ${maximumLogRetention} days.`);

            let title = "CloudWatch Log Groups Retention Updates";

            let lines = [
                `Log Group: ${group.logGroupName}`,
                `Current policy: ${group.retentionInDays ? `${group.retentionInDays} days` : "No expiry"}`,
                `New policy: ${maximumLogRetention} days.`,
            ];

            let items = [
                {
                    colour: "#FF4136",
                    lines: lines
                }
            ];

            messages.push({
                text: title,
                items: items
            });

            logGroupsNeedingUpdated.push(group.logGroupName);
        }
    });

    if (logGroupsNeedingUpdated.length == 0) {
        console.log("No log groups that require updating.");
        return;
    }

    for (let i = 0; i < logGroupsNeedingUpdated.length; i++) {
        const group = logGroupsNeedingUpdated[i];

        await updateLogGroupsRetentionPolicy(group, maximumLogRetention).then(data => {
            console.log(`${group} updated.`);
        }).catch(err => {
            console.error(err);
            throw err;
        });
    }

    await publishToSns(messages).then(data => {

    }).catch(err => {
        console.error(err);
        throw err;
    });
};