#!/bin/bash
# usage: fetch.sh <mac> <request>  copies speed.stdout into runs/
cd ~/anonlib-wt/trees-apple3
tools/cloudmac.sh ssh $1 "cat ~/anonlib-evidence/apple-steward/done/$2/speed.stdout" > ~/anonlib-evidence/trees-apple3/runs/$2.stdout 2>/dev/null
wc -l ~/anonlib-evidence/trees-apple3/runs/$2.stdout
