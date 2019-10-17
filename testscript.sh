#!/bin/bash
echo "This script is used to test Serval Mesh Extender"

#test if enougth arguments

if test "$#" -ne 2; then
	echo "Usage : ./testscript [testInstructionFile] [AddressFile]"
else
	TestFile=$1
	echo "TEST File : $TestFile"
	AddressFile=$2
	echo "ADDRESS File : $AddressFile"
fi


#test first ligne is ok
firstline=$(head -n 1 $TestFile)
if [ "$firstline" != "#!testServalMeshExtenderScript" ]; then
	echo "Test File is not valide, try another one"
	exit 1
fi

#Stoping all node and process of all ME

StopSCRIPT="servald rhizome clean ; servald stop ; servald status;"
USERNAMEMe="root"
PASSWORDMe="root"
USERNAMEMo="root"
PASSWORDMo="root"


:<< 'end_comment'
while read -u10 addrline; do
	#echo $addrline
	stringarray=($addrline)
	meshObs="$(echo ${stringarray[0]} | head -c 2)"
	if [ "$meshObs" != "MO" ];  then	
		sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${stringarray[2]} << end
			${StopSCRIPT} 
end
     #else
     #	echo Stoping MO....
       	#sshpass -p ${PASSWORDMo} ssh -l ${USERNAMEMo} ${stringarray[2]} << end
       			kill $(ps | grep '[c]apture' | awk '{print $1}')
end       	
     fi
done 10< "$AddressFile"
end_comment

#READING TEST FILE

#initialiaze associative array
declare -A SCRIPTFORNODE
declare -A SCRIPTFORMO

:<< 'end_comment'
#Get Actives Mesh Observer
activesMOLine="$(cat ${TestFile} | grep "ActivesMeshObservers")"
#echo $activesMOLine
lineMO=($activesMOLine)
for index in "${lineMO[@]:0}"; do
  #echo $index
  if [ $index != '#' ]; then
    SCRIPTFORMO+=( ["$index"]="capture 192.168.1.134" )
  fi
done

#start MO server on computer 
cd ./


#Print script for each MO and ssh connection
for KEY in "${!SCRIPTFORMO[@]}"; do
  # Print the KEY value
  echo "******MOid: $KEY"
  # Print the VALUE attached to that KEY
  echo "Script: ${SCRIPTFORMO[$KEY]}"

  echo "SSH Connecting ..."
  getlinefromfile="$(cat ${AddressFile} | grep ${KEY})"
  lineinfo=($getlinefromfile)
  #sshpass -p ${PASSWORDMo} ssh ${USERNAMEMo}@${lineinfo[1]} "${SCRIPTFORMO[$KEY]}"
done
end_comment


#get start point of test
startline="$(cat ${TestFile} | grep "Start")"
lineinfo=($startline)
START=${lineinfo[1]}
echo "Charging starting point .... " $START

#get end point of test
endline="$(cat ${TestFile} | grep "End")"
lineinfo=($endline)
END=${lineinfo[1]}
echo "Charging ending point .... " $END

:<< 'end_comment'
#upload Rhizome Bundle File
RhizomeFileName="$(cat ${TestFile} | grep "RhizomeFile")"
lineinfo=($RhizomeFileName)
for index in "${lineinfo[@]:1}"; do
  if [[ -v "SCRIPTFORNODE[${index}]" ]] ; then
    CurrentNode=$index
  elif [[ $index != '#' ]]; then
    #get address
    getlinefromfile="$(cat ${AddressFile} | grep ${CurrentNode})"
    lineinfo=($getlinefromfile)
    sshpass -p ${PASSWORDMe} scp -r rhizomeFile/${index} ${USERNAMEMe}@${lineinfo[2]}:/serval-var/rhizome/
    sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${lineinfo[2]} << fileNameChanged
    	cd /serval-var/rhizome/
    	rm rhizome.db
    	mv ${index} rhizome.db
fileNameChanged
  fi
done
end_comment

# get actives nodes
activesNodesLine="$(cat ${TestFile} | grep "ActivesNodes")"
#echo $activesNodesLine
lineinfo=($activesNodesLine)
for index in "${lineinfo[@]:1}"; do
  #echo $index
  if [ $index != '#' ]; then
    SCRIPTFORNODE+=( ["$index"]="servald start ; " )
  fi
done

#get protocol tested
protocolline="$(cat ${TestFile} | grep "Protocol")"
lineinfo=($protocolline)
if [ ${#lineinfo} -le 16 ]; then
  PROTOCOL=${lineinfo[1]}
  echo "Charging protocol..." $PROTOCOL
  if [ $PROTOCOL == 'LBARD' ]; then
    #stop adhoc WIFI
    for KEY in "${!SCRIPTFORNODE[@]}" ; do
      SCRIPTFORNODE[$KEY]+=" ifconfig adhoc0 down ; " #ajouter LBARD UP
    done
  fi
  if [ $PROTOCOL == 'WIFI' ]; then
    for KEY in "${!SCRIPTFORNODE[@]}"; do
      SCRIPTFORNODE[$KEY]+=" ifconfig adhoc0 up ; " #ajouter LBARD DOWN
    done
  fi
else
  echo "Charging Multiple Protocols..." ${lineinfo[@]:1:${#lineinfo[@]}-2}
  for KEY in "${!SCRIPTFORNODE[@]}"; do
    SCRIPTFORNODE[$KEY]+=" ifconfig adhoc0 up ; " #ajouter LBARD UP
  done
fi


#Get action
actionline="$(cat ${TestFile} | grep "Action")"
lineinfo=($actionline)
ACTION=${lineinfo[1]}
if [ $ACTION == "SendMeshms" ]; then
	#get sender and receiver sid
	getlinefromfilestart="$(cat ${AddressFile} | grep ${START})"
	lineinfostart=($getlinefromfilestart)
	getlinefromfileend="$(cat ${AddressFile} | grep ${END})"	
	lineinfoend=($getlinefromfileend)
	if [ $PROTOCOL == 'WIFI' ]; then
		SCRIPTFORNODE+=( ["${START}"]="servald meshms send message ${lineinfostart[1]}  ${lineinfoend[1]} hiIamworking! ; servald meshms list messages ${lineinfostart[1]}  ${lineinfoend[1]} ;" )
	fi
	if [ $PROTOCOL == 'LBARD' ]; then
		SCRIPTFORNODE+=( ["${START}"]="lbard meshms send ${lineinfostart[1]}  ${lineinfoend[1]} hi!!IamLBARD! ; lbard meshms list messages ${lineinfostart[1]} ${lineinfoend[1]} ;" )
	fi
fi

echo nodes ${!SCRIPTFORNODE[@]}
for KEY in "${!SCRIPTFORNODE[@]}"; do
  	# Print the KEY value
  	echo "MEid:  $KEY"
  	# Print the VALUE attached to that KEY
  	echo "Script: ${SCRIPTFORNODE[$KEY]}"
  	#run script for each ME
  	getlinefromfile="$(cat ${AddressFile} | grep ${KEY})"
  	lineinfo=($getlinefromfile)
  	echo sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${lineinfo[2]}
	sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${lineinfo[2]} << fin
		${SCRIPTFORNODE[$KEY]}
fin
done

sleep 1m
getlinefromfile="$(cat ${AddressFile} | grep ${START})"
	echo lbard meshms list messages ${lineinfostart[1]} ${lineinfoend[1]}
	sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${lineinfo[2]} << fin
		lbard meshms list messages ${lineinfostart[1]} ${lineinfoend[1]}
fin


# left to do :  wait until test is finished and get the MO graph from server + check again if message was received 


