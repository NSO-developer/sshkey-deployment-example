#!/bin/bash
set -eu # Abort the script if a command returns with a non-zero exit code or if
        # a variable name is dereferenced when the variable hasn't been set
NSO_ARCH="arm64" #"x86_64"
NSO_VERSION="6.5"
APP_NAME="app"
NSOAPP_NAME="nsoapp"
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
NSO_DOCKERFILE="Dockerfile.native"

EX_IMG_NAME="ex-img"
NSO_IMG_NAME=$NSO_NAME"-img"

SUBNET=192.168.23.0/24

NCS_IPC_PATH="/tmp/unix-ipc.socket"

# Check that the NSO installer is present
if [ -f nso-$NSO_VERSION.linux.$NSO_ARCH.installer.bin ]
then
    echo "Using:"
    echo "nso-$NSO_VERSION.linux.$NSO_ARCH.installer.bin"
else
    echo >&2 "This demo requires that the NSO SDK installer have been placed in this folder. E.g.:"
    echo >&2 "nso-$NSO_VERSION.linux.$NSO_ARCH.installer.bin"
    echo >&2 "Aborting..."
    exit 1
fi

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

# Get the all the container IDs and stop any running container.
DOCKERPS_EX0=$(docker ps -q -n 1 -f name=$EX0_NAME)
DOCKERPS_EX1=$(docker ps -q -n 1 -f name=$EX1_NAME)
DOCKERPS_EX2=$(docker ps -q -n 1 -f name=$EX2_NAME)
DOCKERPS_NSO=$(docker ps -q -n 1 -f name=$NSO_NAME)

echo "Stop any existing container, then build & run"
if [ ! -z "$DOCKERPS_EX0" ] || [ ! -z "$DOCKERPS_EX1" ] || [ ! -z "$DOCKERPS_EX2" ] || [ ! -z "$DOCKERPS_NSO" ]
then
    docker stop $DOCKERPS_EX0 $DOCKERPS_EX1 $DOCKERPS_EX2 $DOCKERPS_NSO
fi


# Remove an existing network
DOCKERNETLS=$(docker network ls -q -f name=$NET_NAME)
if [ -z "$DOCKERNETLS" ]
then
    echo "Create $NET_NAME"
else
    echo "Remove and recreate any existing $NET_NAME network"
    docker network rm $NET_NAME
fi

# Remove an existing shared volume
DOCKERVOLLS=$(docker volume ls -q -f name=$VOL_NAME)
if [ -z "$DOCKERVOLLS" ]
then
    echo "Create $VOL_NAME"
else
    echo "Remove and recreate any existing $VOL_NAME volume"
    docker volume rm $VOL_NAME
fi

# Build the NSO and netsim ConfD network element images from the two Dockerfiles
docker build -t $EX_IMG_NAME --build-arg NSO_ARCH=$NSO_ARCH --build-arg NSO_VERSION=$NSO_VERSION --build-arg APP_NAME=$APP_NAME -f $EX_DOCKERFILE .
docker build -t $NSO_IMG_NAME --build-arg NCS_IPC_PATH=$NCS_IPC_PATH --build-arg NSO_ARCH=$NSO_ARCH --build-arg NSO_VERSION=$NSO_VERSION --build-arg NSOAPP_NAME=$NSOAPP_NAME --build-arg EX0_IP=$EX0_IP --build-arg EX1_IP=$EX1_IP --build-arg EX2_IP=$EX2_IP --build-arg NSO_HOST_NAME=$NSO_HOST_NAME -f $NSO_DOCKERFILE .

# Create the network
docker network create --subnet=$SUBNET $NET_NAME

# Create a volume
docker volume create --name $VOL_NAME

# Run the NSO and three netsim ConfD network element containers
echo "Run the $EX0_NAME container"
EX0_CID="$(docker run -v $VOL_NAME:/opt/ncs/ncs-$NSO_VERSION --hostname $EX0_NAME --net $NET_NAME --ip $EX0_IP --name $EX0_NAME -d --rm -e EX_NAME=$EX0_NAME -e NSO_VERSION=$NSO_VERSION $EX_IMG_NAME | cut -c1-12)"

while [[ $(docker ps -l -a -q -f status=running | grep $EX0_CID) != $EX0_CID ]]; do
    echo "waiting..."
    sleep .5
done

echo "Run the $EX1_NAME container"
EX1_CID="$(docker run -v $VOL_NAME:/opt/ncs/ncs-$NSO_VERSION --hostname $EX1_NAME --net $NET_NAME --ip $EX1_IP --name $EX1_NAME -d --rm -e EX_NAME=$EX1_NAME -e NSO_VERSION=$NSO_VERSION $EX_IMG_NAME | cut -c1-12)"

while [[ $(docker ps -l -a -q -f status=running | grep $EX1_CID) != $EX1_CID ]]; do
    echo "waiting..."
    sleep .5
done

echo "Run the $EX2_NAME container"
EX2_CID="$(docker run -v $VOL_NAME:/opt/ncs/ncs-$NSO_VERSION --hostname $EX2_NAME --net $NET_NAME --ip $EX2_IP --name $EX2_NAME -d --rm -e EX_NAME=$EX2_NAME -e NSO_VERSION=$NSO_VERSION $EX_IMG_NAME | cut -c1-12)"

while [[ $(docker ps -l -a -q -f status=running | grep $EX2_CID) != $EX2_CID ]]; do
    echo "waiting..."
    sleep .5
done

echo "Run the $NSO_NAME container"
NSO_CID="$(docker run -v $VOL_NAME:/opt/ncs/ncs-$NSO_VERSION --hostname $NSO_NAME --net $NET_NAME --ip $NSO_IP --name $NSO_NAME -d --rm -p 127.0.0.1:2024:2024 -p 127.0.0.1:830:2022 -p 127.0.0.1:443:8888 -e NSO_VERSION=$NSO_VERSION -e NSO_NAME=$NSO_NAME $NSO_IMG_NAME | cut -c1-12)"

echo "Follow the NSO container logs"
docker logs $NSO_NAME --follow
