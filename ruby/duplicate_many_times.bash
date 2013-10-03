#!/bin/bash

# Args: $1 = file name (sehc_aging_report)
#       $2 = file extension (.prpt)
#       $3 = number of times

for i in $(seq 0 $3)
do
    echo "Creating $1$i$2"
    cp "$1$2" "$1$i$2"
done
