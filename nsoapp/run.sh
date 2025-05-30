#!/bin/bash
set -eu # Abort the script if a command returns with a non-zero exit code or if
        # a variable name is dereferenced when the variable hasn't been set
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

printf "\n${PURPLE}###### Setup the example\n${NC}"
printf "${GREEN}##### Regen the NSO SSH server host key\n${NC}"
rm -f ${NCS_CONFIG_DIR}/ssh/*key*
ssh-keygen -N "" -t ed25519 -f ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key
chown -Rh nso:nso ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key*

printf "${GREEN}##### Generate new crypto keys and rotate the crypto keys generated by the NSO installer to the new keys\n${NC}"
# Prefix existing lines with [-1]
sed -i 's/=/\[-1\]=/' "${NCS_CONFIG_DIR}/ncs.crypto_keys"
# Add the external key format line
sed -i '1iEXTERNAL_KEY_FORMAT=2' "${NCS_CONFIG_DIR}/ncs.crypto_keys"
# Generate, append, and load the new keys
NEW_AES128=$(openssl rand -hex 16)
NEW_AES256=$(openssl rand -hex 32)
printf "AESCFB128_KEY[0]=${NEW_AES128}\nAES256CFB128_KEY[0]=${NEW_AES256}\n" >> "${NCS_CONFIG_DIR}/ncs.crypto_keys"
ncs_cmd -d -c "reload"
# Rotate the keys
ncs_cli -n -u admin -g ncsadmin -C << EOF
key-rotation get-active-generation
key-rotation apply-new-keys new-key-generation 0
EOF

printf "${GREEN}##### Add the RESTCONF token authentication script\n${NC}"
cp /${NSOAPP_NAME}/token_auth.sh ${NCS_RUN_DIR}/scripts/

printf "${GREEN}##### Edit the init files\n${NC}"
sed -i.orig -e "s|_EX0_IP_|${EX0_IP}|" \
            -e "s|_EX1_IP_|${EX1_IP}|" \
            -e "s|_EX2_IP_|${EX2_IP}|" \
            /${NSOAPP_NAME}/devices_init.xml

printf "${GREEN}##### Load init files\n${NC}"
for f in /${NSOAPP_NAME}/*_init.xml
do
    ncs_load -d -m -l $f
done

printf "${GREEN}##### Have the CLI use C-style\n${NC}"
ncs_conf_tool -a "    <style>c</style>" ncs-config cli < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Configure RESTCONF token authentication\n${NC}"
ncs_conf_tool -a "    <token-response>
      <x-auth-token>true</x-auth-token>
    </token-response>" ncs-config restconf < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Configure WebUI match-host-name and server-name\n${NC}"
ncs_conf_tool -a "    <server-name>${NSO_HOST_NAME}</server-name>
    <match-host-name>true</match-host-name>" ncs-config webui < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Use a script for RESTCONF token authentication\n${NC}"
ncs_conf_tool -a "    <external-validation>
      <enabled>true</enabled>
      <executable>${NCS_RUN_DIR}/scripts/token_auth.sh</executable>
    </external-validation>" ncs-config aaa < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Enable SSL transport for the WebUI and RESTCONF northbound interfaces\n${NC}"
ncs_conf_tool -e "true" ncs-config webui transport ssl enabled < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Enable SSH transport for the NSO CLI and NETCONF northbound interfaces\n${NC}"
ncs_conf_tool -e "true" ncs-config netconf-north-bound transport ssh enabled < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf
ncs_conf_tool -e "true" ncs-config cli ssh enabled < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Have NSO use Unix domain sockets for UID-based authenticated IPC communication\n${NC}"
ncs_conf_tool -a "  <ncs-local-ipc>
    <enabled>true</enabled>
    <path>${NCS_IPC_PATH}</path>
  </ncs-local-ipc>" ncs-config < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Change the ianach:crypt-hash algorithm from MD5 to use sha-512 - here used for passwords\n${NC}"
ncs_conf_tool -e "sha-512" ncs-config crypt-hash algorithm < ${NCS_CONFIG_DIR}/ncs.conf > ${NCS_CONFIG_DIR}/ncs.conf.tmp && mv -f ${NCS_CONFIG_DIR}/ncs.conf.tmp ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Disable the SNMP agent and change the CLI prompt\n${NC}"
sed -i.bak -e "s|<dir>${NCS_DIR}/etc/ncs/snmp</dir>|<1-- dir>${NCS_DIR}/etc/ncs/snmp</dir -->|"\
           -e 's|@ncs|@nso-\\\H|g' \
           ${NCS_CONFIG_DIR}/ncs.conf

printf "${GREEN}##### Reload ncs.conf to enable the NSO northbound interfaces\n${NC}"
ncs_cmd -d -c "reload"

printf "${GREEN}##### NSO setup done. Set up the NSO CLI and RESTCONF based demos\n${NC}"

printf "${GREEN}#####  NSO CLI and NETCONF client SSH public key authentication for the admin user.\n${NC}"
# To, for example, access the NSO CLI over SSH:
# ssh -i /${NSOAPP_NAME}/mgr_admin_ed25519 -l admin -p 2024 -o LogLevel=ERROR -o UserKnownHostsFile=/${NSOAPP_NAME}/known_hosts "${NSO_NAME}"
ssh-keygen -N "" -t ed25519 -f /${NSOAPP_NAME}/mgr_admin_ed25519
chmod 600 /${NSOAPP_NAME}/mgr_admin_ed25519*
chown nso:nso /${NSOAPP_NAME}/mgr_admin_ed25519*
mkdir -p /home/admin/.ssh
chmod 755 /home/admin/.ssh
chown admin:ncsadmin /home/admin
chmod 755 /home/admin
cat /${NSOAPP_NAME}/mgr_admin_ed25519.pub >> /home/admin/.ssh/authorized_keys
chmod 644 /home/admin/.ssh/authorized_keys
chown -Rh admin:ncsadmin /home/admin/.ssh

printf "${GREEN}#####  SSH client known hosts\n${NC}"
NSO_HOST_KEY=$(cat ${NCS_CONFIG_DIR}/ssh/ssh_host_ed25519_key.pub | cut -d ' ' -f1-2)
printf "[${NSO_NAME}]:2024 $NSO_HOST_KEY\n" > /${NSOAPP_NAME}/known_hosts
chmod 600 /${NSOAPP_NAME}/known_hosts
chown -Rh nso:nso /${NSOAPP_NAME}/known_hosts

printf "${GREEN}#####  NSO RESTCONF client token for the admin user authentication\n${NC}"
restconf_token=$(openssl rand -base64 32)
echo $restconf_token > /home/admin/restconf_token
chown nso:ncsadmin /home/admin/restconf_token
chmod 640 /home/admin/restconf_token

printf "${GREEN}#####  Run the showcase NSO CLI and RESTCONF client scripts\n${NC}"
printf "\n${PURPLE}###### Run an NSO CLI based demo\n${NC}"
/${NSOAPP_NAME}/showcase.sh 3
printf "\n${PURPLE}###### Run an NSO RESTCONF based demo\n${NC}"
python3 -u /${NSOAPP_NAME}/showcase_rc.py 3 $restconf_token
