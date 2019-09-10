//
// Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import ballerina/filepath;
import ballerina/io;
import ballerina/log;

# XML insert operator client.
public type XmlInsertOperator client object {
    JobInfo job;
    SalesforceBaseClient httpBaseClient;

    public function __init(JobInfo job, SalesforceConfiguration salesforceConfig) {
        self.job = job;
        self.httpBaseClient = new(salesforceConfig);
    }

    # Create XML insert batch.
    #
    # + payload - insertion data in XML format
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function insert(xml payload) returns @tainted BatchInfo|ConnectorError {
        xml xmlResponse = check self.httpBaseClient->createXmlRecord([JOB, self.job.id, BATCH], payload);
        return getBatch(xmlResponse);
    }

    # Create XML insert batch using a XML file.
    #
    # + filePath - insertion XML file path
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function insertFile(string filePath) returns @tainted BatchInfo|ConnectorError {
        if (filepath:extension(filePath) == "xml") {
            io:ReadableByteChannel|io:Error rbc = io:openReadableFile(filePath);

            if (rbc is io:Error) {
                string errMsg = "Error occurred while reading the xml file, file: " + filePath;
                log:printError(errMsg, err = rbc);
                IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR, cause = rbc);
                return ioError;
            } else {
                io:ReadableCharacterChannel|io:Error rch = new(rbc, "UTF8");

                if (rch is io:Error) {
                    string errMsg = "Error occurred while reading the xml file, file: " + filePath;
                    log:printError(errMsg, err = rch);
                    IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR, cause = rch);
                    return ioError;
                } else {
                    xml|error fileContent = rch.readXml();

                    if (fileContent is xml) {
                        xml response = check self.httpBaseClient->createXmlRecord([<@untainted> JOB, self.job.id, 
                            <@untainted> BATCH], <@untainted> fileContent);
                        return getBatch(response);
                    } else {
                        string errMsg = "Error occurred while reading the xml file, file: " + filePath;
                        log:printError(errMsg, err = fileContent);
                        IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR, cause = fileContent);
                        return ioError;
                    }
                }
            }
        } else {
            string errMsg = "Invalid file type, file: " + filePath;
            log:printError(errMsg, err = ());
            IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR);
            return ioError;
        }
    }

    # Get XML insert operator job information.
    #
    # + return - JobInfo record if successful else ConnectorError occured
    public remote function getJobInfo() returns @tainted  JobInfo|ConnectorError {
        xml xmlResponse = check self.httpBaseClient->getXmlRecord([JOB, self.job.id]);
        return getJob(xmlResponse);
    }

    # Close XML insert operator job.
    #
    # + return - JobInfo record if successful else ConnectorError occured
    public remote function closeJob() returns @tainted JobInfo|ConnectorError {
        xml xmlResponse = check self.httpBaseClient->createXmlRecord([JOB, self.job.id], XML_STATE_CLOSED_PAYLOAD);
        return getJob(xmlResponse);
    }

    # Abort XML insert operator job.
    #
    # + return - JobInfo record if successful else ConnectorError occured
    public remote function abortJob() returns @tainted JobInfo|ConnectorError {
        xml xmlResponse = check self.httpBaseClient->createXmlRecord([JOB, self.job.id], XML_STATE_ABORTED_PAYLOAD);
        return getJob(xmlResponse);
    }

    # Get XML insert batch information.
    #
    # + batchId - batch ID 
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function getBatchInfo(string batchId) returns @tainted  BatchInfo|ConnectorError {
        xml xmlResponse = check self.httpBaseClient->getXmlRecord([JOB, self.job.id, BATCH, batchId]);
        return getBatch(xmlResponse);
    }

    # Get information of all batches of XML insert operator job.
    #
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function getAllBatches() returns @tainted BatchInfo[]|ConnectorError {
        xml xmlResponse = check self.httpBaseClient->getXmlRecord([JOB, self.job.id, BATCH]);
        return getBatchInfoList(xmlResponse);
    }

    # Retrieve the XML batch request.
    #
    # + batchId - batch ID
    # + return - JSON Batch request if successful else ConnectorError occured
    public remote function getBatchRequest(string batchId) returns @tainted  xml|ConnectorError {
        return self.httpBaseClient->getXmlRecord([JOB, self.job.id, BATCH, batchId, REQUEST]);
    }

    # Get the results of the batch.
    #
    # + batchId - batch ID
    # + numberOfTries - number of times checking the batch state
    # + waitTime - time between two tries in ms
    # + return - Batch result as CSV if successful else ConnectorError occured
    public remote function getResult(string batchId, int numberOfTries = 1, int waitTime = 3000) 
        returns @tainted Result[]|ConnectorError {
        return checkBatchStateAndGetResults(getBatchPointer, getResultsPointer, self, batchId, numberOfTries, waitTime);        
    }
};
