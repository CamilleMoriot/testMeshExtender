#!/bin/bash

echo "Launching test"

compteur=0
nbofloop=10
it=0
#tom script to clear everything

for addr in 01 02 04 05 06 07 09 14
do
    echo "Stopping servald and LBARD on 1$addr"
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 1 | xargs kill"
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 2 | xargs kill"
    echo "Nuking Rhizome database"
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "rm -rvf /serval-var/rhizome/"
    echo ""
done


#while test loop

while [ $it -lt $nbofloop ]
do

  sleep 1m

  echo "STARTING TEST"


  #get random number and push rhizome file
    rand=$[RANDOM%9+1]
    echo $rand
    sshpass -p root2019 ssh metest@192.168.1.41 << end
      sshpass -p root scp -r -o "StrictHostKeyChecking no" rhizome-databases/ 5gig-stress.tar root@192.168.1.10${rand}:/serval-var/
end
    sshpass -p root ssh root@192.168.1.10${rand} <<end
      tar xvf /serval-var/5gig-stress.tar
end




#launch all ME
  for addr in 01 02 04 05 06 07 09 14
  do
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "reboot"
  done



#wait
  sleep 5m

# test loop
  for addr in 01 02 04 05 06 07 09 14
  do
    sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} << end
    rm 1${addr}.txt
    echo servald rhizome list | awk -F ':' '{print \$3}' > 1${addr}.txt
    servald rhizome list | awk -F ':' '{print \$3}' > 1${addr}.txt
    du -s /serval-var/rhizome/ >> 1${addr}.txt
    sort 1${addr}.txt > 1${addr}.txt
end

sshpass -p root2019 ssh metest@192.168.1.41 << end
  rm rhizometest/1${addr}.txt
  sshpass -p root scp -r -o \"StrictHostKeyChecking no\" root@192.168.1.1${addr}:1${addr}.txt rhizometest/1${addr}.txt
end
  done

#test for differences
allsame=true
sshpass -p root2019 ssh metest@192.168.1.41 << end
  cd rhizometest/
  for addr1 in 01 02 04 05 06 07 09 14 ; do
      diff 10${rand}.txt 1\${addr1}.txt
      if [ \$? -eq 0 ]; then
        echo identical
      else
        echo \$?
        $allsame=false
      fi
  done
end

  if [ $allsame=true ] ; then
    compteur=$((compteur+1))
  fi

#tom script to clear everything

  for addr in 01 02 04 05 06 07 09 14
  do
      echo "Stopping servald and LBARD on 1$addr"
      sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 1 | xargs kill"
      sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 2 | xargs kill"
      echo "Nuking Rhizome database"
      sshpass -p root ssh -o "StrictHostKeyChecking no" root@192.168.1.1${addr} "rm -rvf /serval-var/rhizome/"
      echo ""
  done



  it=$((it+1))
done

echo "result are $compteur /$nbofloop"
