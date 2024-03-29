#!/bin/sh

for host in 192.168.1.10{1..6}; do
    echo "Starting LBARD on $host"
    SID=$(sshpass -p root ssh $host "servald start && sleep 5 ; servald id self" | tail -n 1)
    sshpass -p root ssh $host "start-stop-daemon -S -b -x lbard localhost:4110 lbard:lbard $SID $SID /dev/ttyATH0"
done
