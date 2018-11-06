#!/bin/bash

set -e

if [ $# -eq 0 ]; then
  echo "USAGE: $0 plugin1 plugin2 ..."
  exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
DATE=`date '+%Y-%m-%d %H:%M:%S'`

plugin_dir=${SCRIPTPATH}/pluginRepository
include_optional_dependencies="true"

if [ -d "$plugin_dir" ]; then rm -Rf $plugin_dir; fi
mkdir -p "$plugin_dir"

echo "${DATE} Downloading the following plugins and dependencies:" > ${plugin_dir}/downloadedDependencies.txt

downloadJenkinsPluginWithDependencies() {
   dependencyString=$1
   if [[ "$dependencyString" == *";"* ]] && [[ $include_optional_dependencies != "true" ]]; then
      echo "skipping optional dependency $dependencyString"
   else

      if [[ "$dependencyString" == *":"* ]]; then
         dependencyName=$(echo $dependencyString | awk -F ':' '{ print $1 }')
         dependencyVersion=$(echo $dependencyString | awk -F '[:;]' '{ print $2}')
         curl -L --silent --output ${plugin_dir}/$dependencyName.hpi https://updates.jenkins.io/download/plugins/$dependencyName/$dependencyVersion/$dependencyName.hpi
      else
         dependencyName=$dependencyString
         dependencyVersion="LATEST"
         curl -L --silent --output ${plugin_dir}/${dependencyName}.hpi  https://updates.jenkins-ci.org/latest/${dependencyName}.hpi
      fi
      echo "${dependencyName}:${dependencyVersion}" >> ${plugin_dir}/downloadedDependencies.txt

      pluginDependencies=$( unzip -p ${plugin_dir}/${dependencyName}.hpi META-INF/MANIFEST.MF | tr -d '\r' | sed -e ':a;N;$!ba;s/\n //g' | grep -e "^Plugin-Dependencies: " | awk '{ print $2 }' | tr ',' '\n' | tr '\n' ' ')
   
      for jenkinsPlugin in $pluginDependencies; do
         downloadJenkinsPluginWithDependencies $jenkinsPlugin 
      done
   fi
}

for pluginToDownload in $*
do
   downloadJenkinsPluginWithDependencies "$pluginToDownload"
done
