#/bin/bash
pids=/tmp/port_forwardings

if [ -f $pids ]
then
    while read pid;
    do
        echo "Killing $pid"
        kill $pid
    done < $pids
    rm $pids
else
    echo "File $pids not found"
fi