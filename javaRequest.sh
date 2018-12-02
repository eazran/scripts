#!/usr/bin/env bash

# script vars
BASE_FOLDER="/home/app_oss"
BASE_STORAGE="${BASE_FOLDER}/storage"
VAULT_OUT="/prod/cifs_share/Incoming"
SCRIPT_FOLDER="${BASE_FOLDER}/scripts"
REPORT_PROBLEM="${SCRIPT_FOLDER}/reportProblem.sh"

# request vars
REQUEST_ID=$1
REQUEST_BASE_FOLDER="${BASE_STORAGE}/${REQUEST_ID}"
REQUEST_REPOSITORY_FOLDER_NAME="repository"
REQUEST_REPOSITORY_FOLDER="${REQUEST_BASE_FOLDER}/${REQUEST_REPOSITORY_FOLDER_NAME=}"
REQUEST_LOG_FOLDER_NAME="logs"
REQUEST_LOG_FOLDER="${REQUEST_BASE_FOLDER}/${REQUEST_LOG_FOLDER_NAME}"
REQUEST_LOG="${REQUEST_LOG_FOLDER}/request_${REQUEST_ID}.log"
REQUEST_EMAIL=""
DEPENDENCY_GROUP_ID=""
DEPENDENCY_ARTIFACT_ID=""
DEPENDENCY_VERSION=""
DEPENDENCY_TYPE=""
DEPENDENCY_PRODUCT_GROUP=""

load_properties(){
  while read line
  do
    PROPERTY="${line%%=*}"
    case "$PROPERTY" in
      "group_id" ) DEPENDENCY_GROUP_ID="${line#*=}" ;;
      "artifact_id" ) DEPENDENCY_ARTIFACT_ID="${line#*=}" ;;
      "version" ) DEPENDENCY_VERSION="${line#*=}" ;;
      "type" ) DEPENDENCY_TYPE="${line#*=}" ;;
      "request_email" ) REQUEST_EMAIL="${line#*=}" ;;
      "request_group" ) DEPENDENCY_PRODUCT_GROUP="${line#*=}" ;;
    esac

  done <${REQUEST_BASE_FOLDER}/request.java.${REQUEST_ID}
}

# get date for logging
DATE=`date '+%Y-%m-%d %H:%M:%S'`

#Load request properties from file  
if [ -f ${REQUEST_BASE_FOLDER}/request.java.${REQUEST_ID} ]; then
  load_properties
else
  source ${REPORT_PROBLEM} ${REQUEST_ID} "java" ${BASE_STORAGE} ${VAULT_OUT} "File request.java.${REQUEST_ID} does not exist"
  return $?
fi

#Create subfolders
if [ -d "${REQUEST_REPOSITORY_FOLDER}" ]; then rm -Rf ${REQUEST_REPOSITORY_FOLDER}; fi
mkdir ${REQUEST_REPOSITORY_FOLDER}
if [ -d "${REQUEST_LOG_FOLDER}" ]; then rm -Rf ${REQUEST_LOG_FOLDER}; fi
mkdir ${REQUEST_LOG_FOLDER}

echo  $DATE Running Maven to download dependencies for ${DEPENDENCY_ARTIFACT_ID} >> ${REQUEST_LOG}
cd ${REQUEST_BASE_FOLDER}
cp ${SCRIPT_FOLDER}/pom.xml ${REQUEST_BASE_FOLDER}/pom.xml
mvn clean initialize -l ${REQUEST_LOG_FOLDER}/maven.log -DrequestOutputDirectory=${REQUEST_REPOSITORY_FOLDER_NAME} -DrequestGroupId=${DEPENDENCY_GROUP_ID} -DrequestArtifactId=${DEPENDENCY_ARTIFACT_ID} -DrequestVersion=${DEPENDENCY_VERSION}

if grep -q "BUILD FAILURE" "${REQUEST_LOG_FOLDER}/maven.log"; then
  source ${REPORT_PROBLEM} ${REQUEST_ID} "java" ${BASE_STORAGE} ${VAULT_OUT} "Maven build failed. See logs/maven.log"
  return $?
fi

echo  $DATE Running whitesource unified file system agent on ${REQUEST_REPOSITORY_FOLDER} >> ${REQUEST_LOG}
java -jar ${SCRIPT_FOLDER}/whitesource-fs-agent.jar -c ${SCRIPT_FOLDER}/whitesource-fs-agent.config -d ${REQUEST_REPOSITORY_FOLDER} >> "${REQUEST_LOG_FOLDER}/whitesource.log"

if [ $? -ne 0 ]; then
  source ${REPORT_PROBLEM} ${REQUEST_ID} "java" ${BASE_STORAGE} ${VAULT_OUT} "White Source Analysis failed. See ${REQUEST_BASE_FOLDER}/whitesource folder"
  return $?
fi

echo  $DATE Whitesource policy check successful for ${DEPENDENCY_ARTIFACT_ID} >> ${REQUEST_LOG}
echo  $DATE Running Maven to download artifact sources tests and javadoc ${DEPENDENCY_ARTIFACT_ID} >> ${REQUEST_LOG}
# Download sources and javadoc
mvn initialize -DrequestOutputDirectory=${REQUEST_REPOSITORY_FOLDER_NAME} -DrequestGroupId=${DEPENDENCY_GROUP_ID} -DrequestArtifactId=${DEPENDENCY_ARTIFACT_ID} -DrequestVersion=${DEPENDENCY_VERSION} -Dclassifier=sources
mvn initialize -DrequestOutputDirectory=${REQUEST_REPOSITORY_FOLDER_NAME} -DrequestGroupId=${DEPENDENCY_GROUP_ID} -DrequestArtifactId=${DEPENDENCY_ARTIFACT_ID} -DrequestVersion=${DEPENDENCY_VERSION} -Dclassifier=test
mvn initialize -DrequestOutputDirectory=${REQUEST_REPOSITORY_FOLDER_NAME} -DrequestGroupId=${DEPENDENCY_GROUP_ID} -DrequestArtifactId=${DEPENDENCY_ARTIFACT_ID} -DrequestVersion=${DEPENDENCY_VERSION} -Dclassifier=javadoc

# archive libraries to tar
if ! [ -d ${REQUEST_REPOSITORY_FOLDER} ]; then
  source ${REPORT_PROBLEM} ${REQUEST_ID} "java" ${BASE_STORAGE} ${VAULT_OUT} "Nothing was downloaded"
  return $?
fi
cd ${REQUEST_REPOSITORY_FOLDER}
tar -cvf ${REQUEST_BASE_FOLDER}/repository.tar --index-file=${REQUEST_LOG_FOLDER}/tar.log *

# put success file
touch ${REQUEST_LOG_FOLDER}/success

# archive all relevant files of the request to tar
cd ${REQUEST_BASE_FOLDER}
tar -cf ${REQUEST_ID}.java.tar repository.tar ${REQUEST_LOG_FOLDER_NAME}/ whitesource/

# move archive to vault_out
mv ${REQUEST_BASE_FOLDER}/${REQUEST_ID}.java.tar ${VAULT_OUT}/

# delete rest
cd ${BASE_STORAGE}
#rm -rf ${REQUEST_BASE_FOLDER}

