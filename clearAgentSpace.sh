#!/bin/bash
#
# PreReq : Install bamboo agent API plugin - https://marketplace.atlassian.com/plugins/com.edwardawebb.bamboo-agent-apis
#https://marketplace.atlassian.com/plugins/com.edwardawebb.bamboo-agent-apis
#https://eddiewebb.atlassian.net/wiki/display/AAFB/Access+Token+Operations
#https://bitbucket.org/eddiewebb/bamboo-agent-apis
# API Version tested on  : 2.0
#Define the location of multiple bamboo agents

declare -a agentLocations=("/opt/data/bamboo-agents/agent1-home")
bambooUrl='http://mybamboo.com'

# Make temp directory
TMPFILE=`mktemp -d /tmp/clearAgentSpace.XXXXXX` || exit 1
find ${TMPFILE} -type d -exec chmod 0755 {} \;

# To extract property value from JSON response
# https://gist.github.com/cjus/1047794
function jsonValue() {
  KEY=$1
  num=$2
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p
}

for agentLocation in ${agentLocations[@]}
do
    #Check if the file exist
    if [ -e "${agentLocation}/bamboo-agent.cfg.xml" ]
        then
           agentId=`cat ${agentLocation}/bamboo-agent.cfg.xml | grep -oPm1 "(?<=<id>)[^<]+"`
           buildWorkingDir=`cat ${agentLocation}/bamboo-agent.cfg.xml | grep -oPm1 "(?<=<buildWorkingDirectory>)[^<]+"`
            #grab uuid for this environment of local path
           uuid=`cat /opt/data/bamboo-agents/token.uuid`
           # Check if both variables are not null
           if [[  -z ${agentId} ]] || [[ -z ${buildWorkingDir} ]] || [[ -z ${uuid} ]]
            then
              echo "$(date): agentId or buildWorkingDir or uuid not found" >> $TMPFILE/log.txt
            else
               echo "$(date): Agent ID ${agentId}" >> $TMPFILE/log.txt
               echo "$(date): Artifacts location ${buildWorkingDir}" >> $TMPFILE/log.txt
               echo "$(date): uuid ${uuid}"  >> $TMPFILE/log.txt
               echo "$(date): Running Disk Purge for Agent $agentId"  >> $TMPFILE/log.txt
               #check for required libraries/tools and setup tempdir
               command -v curl >/dev/null 2>&1 || { echo "$(date): Required tool 'curl' not found" >> $TMPFILE/log.txt ;exit 2; }
               
               

              # disable agent in bamboo
              echo
              echo "$(date) Disabling the agent and checking status" >> $TMPFILE/log.txt
              curl -k -c $TMPFILE/cookies "$bambooUrl" > /dev/null 2>&1
              curl -X POST -k -b $TMPFILE/cookies "$bambooUrl/rest/agents/1.0/$agentId/state/disable?uuid=${uuid}" > /dev/null 2>&1
              # Once the agent is disabled wait for about 2 minutes. Observed a latency between the agent starting to perform a job and the bamboo server
              # realizing the agent is busy
              echo "$(date): Sleeping for 120 seconds to give a chance for the bamboo server to get updated info. Messaging delay benifit of doubt"  >> $TMPFILE/log.txt
              sleep 120
              # Check current agent status

              echo "$(date): Proceeding with monitoring the status until agent is idle"  >> $TMPFILE/log.txt
              curl -k -b $TMPFILE/cookies "$bambooUrl/rest/agents/1.0/$agentId/state/text?uuid=${uuid}" -o $TMPFILE/state.txt 2>/dev/null
              agentStatus=`cat $TMPFILE/state.txt | jsonValue enabled` 
              busy=`cat $TMPFILE/state.txt | jsonValue busy` 
              echo "$(date): Is the agent busy? $busy"  >> $TMPFILE/log.txt
              echo "$(date): Is the agent enabled? $agentStatus"  >> $TMPFILE/log.txt
              if [ "$busy"  == "true" ]; then
                  echo "$(date): Agent is still running a job, waiting ..\n"  >> $TMPFILE/log.txt
                  # while polling, and is still running, sleep
                  running=1
                  while [ $running -eq 1 ]
                  do
                      sleep 10
                      curl -k -b $TMPFILE/cookies "$bambooUrl/rest/agents/1.0/$agentId/state/text?uuid=${uuid}" -o $TMPFILE/state.txt 2>/dev/null
                      busy=`cat $TMPFILE/state.txt | jsonValue busy`
                      echo "$(date): Is the agent busy? $busy"  >> $TMPFILE/log.txt
                      if [ "$busy"  == "false" ]; then
                          echo "$(date): Yay, it's idle now!\n"  >> $TMPFILE/log.txt
                          break
                      else
                          echo "$(date): still busy..\n"  >> $TMPFILE/log.txt
                      fi #  if [ "$busy"  == "false" ]; then
                  done #do
              fi #  if [ "$busy"  == "true" ]; then

               # run clear disk commands for build-dir older then 30 days.

              echo "$(date): Agent is disabled and idle, starting cleanup"  >> $TMPFILE/log.txt
              #delete files in build-dir as bamboo user, so the script can't do any havoc by deleting what isn't not supposed to. 
              #If something bad happens bamboo user doesn't have enough permission

              sudo -u bamboo  echo ${buildWorkingDir}   

              sudo -u bamboo  rm -rf ${buildWorkingDir} 
              #Remove npm cache, temp files, kill phamtomJS process etc
              
              echo "$(date): Disk clear activities complete."  >> $TMPFILE/log.txt
              echo "$(date): Disk Info\n"  >> $TMPFILE/log.txt
              df -h | sed -e 's/^/\'$'\t/g'  >> $TMPFILE/log.txt

              # reenable agent after the clearn
              # Enable 
              echo ""  >> $TMPFILE/log.txt
              echo "$(date): re-enabling the agent"  >> $TMPFILE/log.txt
              curl -X POST -k -b $TMPFILE/cookies "$bambooUrl/rest/agents/1.0/$agentId/state/enable?uuid=${uuid}" > /dev/null 2>&1

              # Check current agent status
              curl -k -b $TMPFILE/cookies "$bambooUrl/rest/agents/1.0/$agentId/state/text?uuid=${uuid}" -o $TMPFILE/state.txt 2>/dev/null
              agentStatus=`cat $TMPFILE/state.txt | jsonValue enabled` 
              busy=`cat $TMPFILE/state.txt | jsonValue busy` 
              echo "$(date): Is the agent enabled? $agentStatus"  >> $TMPFILE/log.txt
              echo ""  >> $TMPFILE/log.txt
              echo "$(date): Complete"  >> $TMPFILE/log.txt

           fi  # if [[  -z ${agentId} ]] || [[ -z ${buildWorkingDir} ]] || [[ -z ${uuid} ]]

        else #if [ -e "${agentLocation}/bamboo-agent.cfg.xml" ]
           echo "$(date): Agent configuration information not found at ${agentLocation}/bamboo-agent.cfg.xml"   >> $TMPFILE/log.txt 
           #uncomment the exit when using in shell script
           # exit 1
    fi #if [ -e "${agentLocation}/bamboo-agent.cfg.xml" ]
 done #do for agentLocation in ${agentLocations[@]}