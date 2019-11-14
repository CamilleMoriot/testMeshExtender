#!/bin/bash

# Stop services and destroy Rhizome content
for host in meshex{1..14}; do
    echo "Stopping servald and LBARD on $host"
    sshpass -p root ssh $host "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 1 | xargs kill"
    sshpass -p root ssh $host "ps | grep -E \"(servald)|(lbard)\" | cut -d ' ' -f 2 | xargs kill"
    echo "Nuking Rhizome database"
    sshpass -p root ssh $host "rm -rvf /serval-var/rhizome/"
    echo ""
done
