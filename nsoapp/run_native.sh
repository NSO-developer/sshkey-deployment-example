#!/bin/bash
set -eu # Abort the script if a command returns with a non-zero exit code or if
        # a variable name is dereferenced when the variable hasn't been set
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

printf "\n${PURPLE}###### Reset and setup the example\n${NC}"

printf "${GREEN}##### Reset\n${NC}"
make -f Makefile.native stop &> /dev/null
make -f Makefile.native clean

printf "${GREEN}##### Regen the NSO SSH server host key to not store it in a container layer\n${NC}"
ssh-keygen -N "" -t ed25519 -f ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key
chmod 644 ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key.pub
chmod 440 ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key
chown -Rh admin:ncsadmin ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key*

printf "${GREEN}##### Regen crypto keys\n${NC}"
NEW_AES128=$(openssl rand -hex 16)
NEW_AES256=$(openssl rand -hex 32)
printf "EXTERNAL_KEY_FORMAT=2\nAESCFB128_KEY[0]=${NEW_AES128}\nAES256CFB128_KEY[0]=${NEW_AES256}\n" > "${NCS_CONFIG_DIR}/ncs.crypto_keys"

printf "${GREEN}##### Start a cron job taht Log rotate the NSO logs 14 minutes past the hour every hour saving the past 24 logs. I.e. past 24h\n${NC}"
sed -i.orig -e "s|_NSO_LOG_DIR_|${NCS_LOG_DIR}|" /${NSOAPP_NAME}/logrotate.conf
runuser -m -u admin -g ncsadmin -- crontab - <<< "14 * * * * /usr/sbin/logrotate /${NSOAPP_NAME}/logrotate.conf --state /${NSOAPP_NAME}/logrotate-state"
crond

printf "${GREEN}##### Set up and start NSO from the admin user\n${NC}"
runuser -m -u admin -g ncsadmin -- make -f Makefile.native all start

printf "${GREEN}##### NSO setup done. Set up the NSO CLI and RESTCONF based demos\n${NC}"

printf "${GREEN}##### NSO CLI and NETCONF client SSH public key authentication for the admin user.\n${NC}"
# To, for example, access the NSO CLI over SSH:
# ssh -i /${NSOAPP_NAME}/mgr_admin_ed25519 -l admin -p 2024 -o LogLevel=ERROR -o UserKnownHostsFile=/${NSOAPP_NAME}/known_hosts "${NSO_NAME}"
ssh-keygen -N "" -t ed25519 -f /${NSOAPP_NAME}/mgr_admin_ed25519
chmod 600 /${NSOAPP_NAME}/mgr_admin_ed25519.pub
chmod 600 /${NSOAPP_NAME}/mgr_admin_ed25519
mkdir -p /home/admin/.ssh
chmod 750 /home/admin/.ssh
cat mgr_admin_ed25519.pub >> /home/admin/.ssh/authorized_keys
chmod 640 /home/admin/.ssh/authorized_keys
chown -Rh admin:ncsadmin /home/admin/.ssh

printf "${GREEN}##### SSH client known hosts\n${NC}"
NSO_HOST_KEY=$(cat ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key.pub | cut -d ' ' -f1-2)
printf "[${NSO_NAME}]:2024 $NSO_HOST_KEY\n" > /${NSOAPP_NAME}/known_hosts
chmod 600 /${NSOAPP_NAME}/known_hosts

printf "${GREEN}##### NSO RESTCONF client token for the admin user authentication\n${NC}"
restconf_token=$(openssl rand -base64 32)
echo $restconf_token > /home/admin/restconf_token
chown admin:ncsadmin /home/admin/restconf_token
chmod 640 /home/admin/restconf_token

printf "${GREEN}##### Run the showcase NSO CLI and RESTCONF client scripts\n${NC}"
printf "\n${PURPLE}###### Run an NSO CLI based demo\n${NC}"
/${NSOAPP_NAME}/showcase.sh 3
printf "\n${PURPLE}###### Run an NSO RESTCONF based demo\n${NC}"
python3 -u /${NSOAPP_NAME}/showcase_rc.py 3 $restconf_token
cd /${NSOAPP_NAME}

tail -F $NCS_LOG_DIR/ncs-python-vm-distkey.log
