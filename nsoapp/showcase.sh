#!/bin/bash

# An NSO nano service example. A CLI SSH client that use a service to setup
# public key authentication with NETCONF SSH network elements and then revert
# back to password authentication.

set -eu # Abort the script if a command returns with a non-zero exit code or if
        # a variable name is dereferenced when the variable hasn't been set

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

function on_nso() { printf "${PURPLE}On NSO CLI: ${NC}$1\n"; ssh -i /${NSOAPP_NAME}/mgr_admin_ed25519 -l admin -p 2024 -o LogLevel=ERROR -o UserKnownHostsFile=/${NSOAPP_NAME}/known_hosts "${NSO_NAME}" "$1" ; }
function on_nso2() { ssh -i /${NSOAPP_NAME}/mgr_admin_ed25519 -l admin -p 2024 -o LogLevel=ERROR -o UserKnownHostsFile=/${NSOAPP_NAME}/known_hosts "${NSO_NAME}" "$1" ; }

printf "\n${PURPLE}##### Generate keys, distribute the public key and configure NSO for public key authentication with $1 network elements\n${NC}"
NES=""
i=0
while [ $i -lt $1 ]; do
    NES+="pubkey-dist key-auth ex$i admin remote-name admin authgroup-name ex$i-admin passphrase \"GThunberg18!\";"
    i=$(($i+1))
done

until on_nso "show ncs-state daemon-status"; do
    printf "${RED}##### Waiting for NSO to reload the configuration...\n${NC}"
    sleep .5
done

on_nso "devices fetch-ssh-host-keys ; devices sync-from"
on_nso "config; $NES commit dry-run ; commit"

echo ""

NES=()
i=0
while [ $i -lt $1 ]; do
    NES+=("ex$i")
    i=$(($i+1))
done

for NE in "${NES[@]}"
do
    while : ; do
        arr=($(on_nso2 "show pubkey-dist key-auth $NE admin plan component self self state ready status"))
        if [[ ${arr[1]} == "reached"* ]]; then
            printf "${GREEN}##### $NE deployed\n${NC}"
            break
        fi
        printf "${RED}##### Waiting for $NE to reach the ncs:ready state...\n${NC}"
        sleep 1
    done
done

printf "\n${PURPLE}###### Show the plan status\n${NC}"
on_nso "show pubkey-dist key-auth plan component | tab"

printf "\n${PURPLE}###### Show the configuration added to NSO and network elements\n${NC}"
on_nso "show running-config devices authgroups group umap admin | nomore ; show running-config devices device authgroup | nomore ; show running-config devices device config aaa authentication users user admin authkey | nomore"

printf "\n${PURPLE}###### List the generated private and public keys\n${NC}"
ls -la ${NCS_RUN_DIR}/*ed25519*

printf "\n${PURPLE}###### Delete the nano service to go back from public key to password based network element authentication\n${NC}"
i=5
while [ $i -gt 0 ]; do
    printf "${PURPLE}$i\n${NC}"
    sleep 1
    i=$(($i-1))
done

on_nso "config ; no pubkey-dist ; commit dry-run ; commit"

echo ""
res="-1"
while [[ "$res" != "0"* ]]; do
    arr=($(on_nso2 "show zombies service | icount"))
    res=${arr[1]}
    printf "${RED}##### Waiting for $res nano service instances to be deleted...\n${NC}"
    sleep 1
done

printf "\n${PURPLE}###### Show the restored configuration for password authentication\n${NC}"
on_nso "show running-config devices authgroups group umap admin | nomore ; show running-config devices device authgroup | nomore ; show running-config devices device config aaa authentication users user admin authkey | nomore"

printf "\n\n${GREEN}##### Done!\n${NC}"
