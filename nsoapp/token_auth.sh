#!/bin/bash
set -eu # Abort the script if a command returns with a non-zero exit code or if
        # a variable name is dereferenced when the variable hasn't been set
read -r token_str
auth_token=$(echo "$token_str" | grep -o -P '(?<=\[).*(?=;)')
admin_token="$(cat /home/admin/restconf_token)"
if [ "$auth_token" == "$admin_token" ]
then
    printf "accept $(id -G -n admin) $(id -u admin) $(id -G admin) $(eval echo "~admin") admin\n"
else
    printf "reject\n"
fi
