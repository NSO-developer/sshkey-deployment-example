#!/bin/bash
while [ ! -f /opt/ncs/ncs-${NSO_VERSION}/ncsrc ]
do
    echo "Waiting for the NSO container shared volume to appear"
    sleep 0.2
done

while [ ! -f /opt/ncs/ncs-${NSO_VERSION}/netsim/confd/confdrc ]
do
    echo "Waiting for the NSO container shared volume to appear"
    sleep 0.2
done

source /opt/ncs/ncs-${NSO_VERSION}/ncsrc
source /opt/ncs/ncs-${NSO_VERSION}/netsim/confd/confdrc
# Install the netsim ConfD application
make all

# Start the netsim ConfD instance
${CONFD_DIR}/bin/confd -c confd.conf --addloadpath ${CONFD_DIR}/etc/confd

# Start a Python application that subscribes to authkey list changes and
# sync the changes with the users authorized keys file.
python3 ssh_authkey.py 4565 &

tail -F /${APP_NAME}/logs/ssh-authkey.log
