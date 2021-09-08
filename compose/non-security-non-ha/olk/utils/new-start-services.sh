#!/usr/bin/env bash


#Init, if not already, and start Hive Metastore and HiveService2
bash /hive/bin/start-services.sh &
sleep 3

#start olk service
launcher run
