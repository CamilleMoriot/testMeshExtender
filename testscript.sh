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

USERNAMEMe="root"
PASSWORDMe="root"
USERNAMEMo="root"
PASSWORDMo="root"



while read -u10 addrline; do
	#echo $addrline
	stringarray=($addrline)
	meshObs="$(echo ${stringarray[0]} | head -c 2)"
	if [ "$meshObs" != "MO" ];  then
		echo Stoping ${stringarray[0]}
		sshpass -p root ssh -o "StrictHostKeyChecking no" root@${stringarray[2]} "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 1 | xargs kill"
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@${stringarray[2]} "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 2 | xargs kill"
    echo "Nuking Rhizome database"
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@${stringarray[2]} "rm -rvf /serval-var/rhizome/"
     else
     		echo Stoping ${stringarray[0]}
       	sshpass -p ${PASSWORDMo} ssh -o "StrictHostKeyChecking no" -l ${USERNAMEMo} ${stringarray[1]} << end
       			kill $(ps | grep '[c]apture' | awk '{print $1}')
end
     fi
done 10< "$AddressFile"


#READING TEST FILE

#initialiaze associative array
declare -A SCRIPTFORNODE
declare -A SCRIPTFORMO


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
    sshpass -p ${PASSWORDMe} scp -r rhizomeFile/${index} ${USERNAMEMe}@${lineinfo[2]}:/serval-var/
    sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${lineinfo[2]} << fileNameChanged
    	tar xvf /serval-var/${index}
fileNameChanged
  fi
done


# get actives nodes
activesNodesLine="$(cat ${TestFile} | grep "ActivesNodes")"
#echo $activesNodesLine
lineinfo=($activesNodesLine)
for index in "${lineinfo[@]:1}"; do
  #echo $index
  if [ $index != '#' ]; then
    SCRIPTFORNODE+=( ["$index"]=" servald start ; " )
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
			sidline="$(cat ${AddressFile} | grep $KEY)"
			lineinfo=($sidline)
			SID=${lineinfo[1]}
      SCRIPTFORNODE[$KEY]+=" ifconfig adhoc0 down ; ../etc/serval/runlbard & " #ajouter LBARD UP
    done
  fi
  if [ $PROTOCOL == 'WIFI' ]; then
    for KEY in "${!SCRIPTFORNODE[@]}"; do
      SCRIPTFORNODE[$KEY]+=" ifconfig adhoc0 up ; "
    done
  fi
else
  echo "Charging Multiple Protocols..." ${lineinfo[@]:1:${#lineinfo[@]}-2}
  for KEY in "${!SCRIPTFORNODE[@]}"; do
		sidline="$(cat ${AddressFile} | grep $KEY)"
		lineinfo=($sidline)
		SID=${lineinfo[1]}
    SCRIPTFORNODE[$KEY]+=" ifconfig adhoc0 up ; ../etc/serval/runlbard & " #ajouter LBARD UP
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

#Get Actives Mesh Observer
activesMOLine="$(cat ${TestFile} | grep "ActivesMeshObservers")"
echo $activesMOLine
lineMO=($activesMOLine)
for index in "${lineMO[@]:1}"; do
  echo $index
  if [ $index != '#' ]; then
		if [ $PROTOCOL == 'WIFI' ]; then
    	SCRIPTFORMO+=( ["$index"]="capture --nouhf 192.168.1.41 & " )
		fi
		if [ $PROTOCOL == 'LBARD' ]; then
    	SCRIPTFORMO+=( ["$index"]="capture --nowifi 192.168.1.41 & " )
		fi
  fi
done

#start MO server on computer
	cd /home/metest/serval-mesh-observer-packet-capture/server/
 	./svrCap &
	cd /home/metest/testMeshExtender

#Print script for each MO and ssh connection
for KEY in "${!SCRIPTFORMO[@]}"; do
  # Print the KEY value
  echo "******MOid: $KEY"
  # Print the VALUE attached to that KEY
  echo "Script: ${SCRIPTFORMO[$KEY]}"
  getlinefromfile="$(cat ${AddressFile} | grep ${KEY})"
	echo $getlinefromfile
  lineinfo=($getlinefromfile)
  sshpass -p ${PASSWORDMo} ssh  ${USERNAMEMo}@${lineinfo[1]} "${SCRIPTFORMO[$KEY]}"
done




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

sleep 2m
getlinefromfile="$(cat ${AddressFile} | grep ${START})"
	sshpass -p ${PASSWORDMe} ssh ${USERNAMEMe}@${lineinfo[2]} << fin
		servald meshms list messages ${lineinfostart[1]} ${lineinfoend[1]}
fin
 ps | grep svr | cut -d ' ' -f 1 | xargs kill -SIGINT
