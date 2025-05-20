#!/bin/bash
set -eu # Abort the script if a command returns with a non-zero exit code or if
        # a variable name is dereferenced when the variable hasn't been set

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

NSO_VERSION="6.5"
NSO_CONTAINER_VERSION="6.5"
APP_NAME="app"
NSOAPP_NAME="nsoapp"
NSOAPP_DIR=$(pwd)/$NSOAPP_NAME
NET_NAME="ExampleNet"
VOL_NAME="nsoshare"
EX0_NAME="ex0"
EX0_IP="192.168.23.99"
EX1_NAME="ex1"
EX1_IP="192.168.23.98"
EX2_NAME="ex2"
EX2_IP="192.168.23.97"
NSO_NAME="nso"
NSO_IP="192.168.23.2"
NSO_HOST_NAME="my-host.com"
EX_DOCKERFILE="Dockerfile.confd"

EX_IMG_NAME="ex-img"
NSO_IMG_NAME="cisco-nso-prod:$NSO_CONTAINER_VERSION"
NSO_BUILDIMG_NAME="cisco-nso-build:$NSO_CONTAINER_VERSION"

SUBNET=192.168.23.0/24

NCS_IPC_PATH="/tmp/unix-ipc.socket"

printf "NCS_IPC_PATH=$NCS_IPC_PATH\nSUBNET=$SUBNET\nNSO_HOST_NAME=$NSO_HOST_NAME\nNSOAPP_NAME=$NSOAPP_NAME\nNSOAPP_DIR=$NSOAPP_DIR\nNSO_NAME=$NSO_NAME\nNSO_IP=$NSO_IP\nNSO_IMG_NAME=$NSO_IMG_NAME\nNSO_BUILDIMG_NAME=$NSO_BUILDIMG_NAME\nNSO_VERSION=$NSO_VERSION\nEX0_NAME=$EX0_NAME\nEX0_IP=$EX0_IP\nEX1_NAME=$EX1_NAME\nEX1_IP=$EX1_IP\nEX2_NAME=$EX2_NAME\nEX2_IP=$EX2_IP\nEX_IMG_NAME=$EX_IMG_NAME\nAPP_NAME=$APP_NAME\nEX_DOCKERFILE=$EX_DOCKERFILE\nsrcdir=''\n" > ./.env

# Check that the netsim ConfD network element application directory is present and compress it
if [ -d $APP_NAME ]
then
    echo "Using this application folder:"
    printf "%s\n" "$APP_NAME"
    rm -f $APP_NAME.tar.gz
    tar cfz $APP_NAME.tar.gz $APP_NAME
else
    echo >&2 "This demo require that the application folder exists"
    echo >&2 "E.g. this directory:"
    echo >&2 "./$APP_NAME"
    echo >&2 "Aborting..."
    exit 1
fi

# Check that the NSO client application directory is present and compress it
if [ -d $NSOAPP_NAME ]
then
    echo "Using this application folder:"
    printf "%s\n" "$NSOAPP_NAME"
    rm -f $NSOAPP_NAME.tar.gz
    tar cfz $NSOAPP_NAME.tar.gz $NSOAPP_NAME
else
    echo >&2 "This demo require that the manager application folder exists"
    echo >&2 "E.g. this directory:"
    echo >&2 "./$NSOAPP_NAME"
    echo >&2 "Aborting..."
    exit 1
fi

printf "${GREEN}##### Reset the container setup\n${NC}"
docker compose --profile nso down -v
docker compose --profile example down -v

docker compose build NODE-NSO NODE-EX0 NODE-EX1 NODE-EX2

printf "\n${GREEN}##### Build the NSO packages\n${NC}"
docker compose --profile build up

printf "\n${GREEN}##### Start the NSO container\n${NC}"
docker compose --profile nso up --wait

printf "\n${GREEN}##### Start the three netsim ConfD network element containers\n${NC}"
docker compose --profile example up --wait

printf "\n${GREEN}##### Run a demo from the NSO node\n${NC}"
printf "${RED}##### Press any key to continue or ctrl-c to exit\n${NC}"
read -n 1 -s -r
docker cp $NSOAPP_NAME.tar.gz $NSO_NAME:/
docker exec --user root $NSO_NAME sh -c "mkdir $NSOAPP_NAME; chown nso:nso $NSOAPP_NAME"
docker exec $NSO_NAME sh -c "tar xfz $NSOAPP_NAME.tar.gz"
docker exec --user root $NSO_NAME /$NSOAPP_NAME/run.sh

printf "\n${GREEN}##### Follow the NODE-EX0 NODE-EX1 NODE-EX2 NODE-NSO logs\n${NC}"
printf "${RED}##### Press any key to continue or ctrl-c to exit\n${NC}"
read -n 1 -s -r
docker compose logs --follow NODE-NSO
