const AWSXRay = require('aws-xray-sdk');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));

async function getLogGroups(nextToken) {
    var client = new AWS.CloudWatchLogs({
        region: process.env.AWS_REGION
    });

    return new Promise((resolve, reject) => {
        var params = {
            limit: '2'
        };

        if (nextToken){
            params.nextToken = nextToken;
        }
        client.describeLogGroups(params, function (err, data) {
            if (err) { 
                console.log(err, err.stack); 
                reject(err);
            }
            else { 
                console.log(data);
                resolve(data);
            }
        });
    });
}


exports.handler = async (event, context) => {
    let nextToken = "";
    await getLogGroups(nextToken).then(
        
    ).catch(err => {
        console.error(err);
        throw err;
    });
};