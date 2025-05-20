#!/usr/bin/env python3

"""
An NSO nano service example. A CLI SSH client that use a service to setup
public key authentication with NETCONF SSH network elements and then revert
back to password authentication.

See the README file for more information
"""
import os
import time
import sys
from datetime import datetime
import json
import requests

BASE_URL = 'https://127.0.0.1:8888/restconf'
HEADER = '\033[95m'
OKBLUE = '\033[94m'
OKGREEN = '\033[92m'
ENDC = '\033[0m'
BOLD = '\033[1m'

NNES = int(sys.argv[1])
token = sys.argv[2]
nso_host_name = os.getenv('NSO_HOST_NAME')

requests.packages.urllib3.disable_warnings(
    requests.packages.urllib3.exceptions.InsecureRequestWarning)
headers = {'Content-Type': 'application/yang-data+json',
           'X-Auth-Token': f'{token}', 'Host': nso_host_name}
headers_patch = {'Content-Type': 'application/yang-patch+json',
                 'X-Auth-Token': f'{token}', 'Host': nso_host_name}
headers_stream = {'Content-Type': 'text/event-stream',
                  'X-Auth-Token': f'{token}', 'Host': nso_host_name}

PATH = '/operations/tailf-ncs:devices/fetch-ssh-host-keys'
print(f"{BOLD}POST " + BASE_URL + PATH + f"{ENDC}")
r = requests.post(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

PATH = '/operations/tailf-ncs:devices/sync-from'
print(f"{BOLD}POST " + BASE_URL + PATH + f"{ENDC}")
r = requests.post(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

print(f'\n{OKBLUE}##### Generate keys, distribute the public key and'
      f'configure NSO for public key authentication with {NNES} network'
      f' elements\n{ENDC}')
EDIT_LIST = []
for i in range(0, NNES):
    dk_data = {}
    dk_data["ne-name"] = f"ex{i}"
    dk_data["local-user"] = "admin"
    dk_data["remote-name"] = "admin"
    dk_data["authgroup-name"] = f"ex{i}-admin"
    dk_data["passphrase"] = "GThunberg18!"
    edit_data = {}
    edit_data["edit-id"] = f"edit{i}"
    edit_data["operation"] = "create"
    edit_data["target"] = f"/distkey:pubkey-dist/key-auth=ex{i},admin"
    edit_data["value"] = {"distkey:key-auth": [dk_data]}
    EDIT_LIST.append(edit_data)
PATCH_DATA = {}
PATCH_DATA["patch-id"] = "add-pubkey"
PATCH_DATA["edit"] = EDIT_LIST
INPUT_DATA = {"ietf-yang-patch:yang-patch": PATCH_DATA}

PATH = '/data?dry-run'
print(f"{BOLD}PATCH " + BASE_URL + PATH + f"{ENDC}")
print(f"{HEADER}" + json.dumps(INPUT_DATA, indent=2) + f"{ENDC}")
r = requests.patch(BASE_URL + PATH, json=INPUT_DATA, headers=headers_patch,
                   verify=False)
print(json.dumps(r.json(), indent=2))

dt_string = datetime.utcnow().isoformat()

PATH = '/data'
print(f"{BOLD}PATCH " + BASE_URL + PATH + f"{ENDC}")
print(f"{HEADER}" + json.dumps(INPUT_DATA, indent=2) + f"{ENDC}")
r = requests.patch(BASE_URL + PATH, json=INPUT_DATA, headers=headers_patch,
                   verify=False)
print(f'Status code: {r.status_code}\n')

print(f"\n{HEADER}##### Waiting for plan notifications for all created nano"
      f" service components to have reached the ready state...{ENDC}")
PATH = '/streams/service-state-changes/json?start-time=' + dt_string
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
with requests.get(BASE_URL + PATH, headers=headers_stream, stream=True,
                  verify=False) as r:
    for notifs_str in r.iter_content(chunk_size=None, decode_unicode=True):
        notifs_str = notifs_str.replace('data: ', '')
        print(f"{HEADER}" + notifs_str + f"{ENDC}")
        notifications = notifs_str.split("\n\n")
        NREADY = 0
        for notif_str in notifications:
            if len(notif_str):
                notif = json.loads(notif_str)
                state = notif["ietf-restconf:notification"]\
                             ["tailf-ncs:plan-state-change"]\
                             ["state"]
                operation = notif["ietf-restconf:notification"]\
                                 ["tailf-ncs:plan-state-change"]\
                                 ["operation"]
                status = notif["ietf-restconf:notification"]\
                              ["tailf-ncs:plan-state-change"]\
                              ["status"]
                if ("tailf-ncs:ready" in state and operation == "modified" and
                   status == "reached"):
                    NREADY += 1
        if NREADY == NNES:
            break

PATH = '/operations/distkey:pubkey-dist/key-auth=ex0,admin/check-sync'
print(f"{BOLD}POST " + BASE_URL + PATH + f"{ENDC}")
r = requests.post(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

print(f'\n{OKBLUE}###### Show the plan status\n{ENDC}')
PATH = '/data/distkey:pubkey-dist?fields=key-auth/plan/' +\
       'component(type;name;state(name;status;post-action-status))'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

print(f'\n{OKBLUE}###### Show the configuration added to NSO and network'
      f' elements\n{ENDC}')
PATH = '/data/tailf-ncs:devices/authgroups?fields=group(name;umap)'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

PATH = '/data/tailf-ncs:devices?fields=device(authgroup)'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

PATH = '/data/tailf-ncs:devices?fields=device/config/tailf-aaa:aaa/' +\
       'authentication/users/user(name;ssh-authkey:authkey)'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

print(f'\n{OKBLUE}###### The generated private and public keys\n{ENDC}')
for f_name in os.listdir('.'):
    if "ed25519" in f_name:
        print(f_name)

print(f'\n{OKBLUE}###### Delete the nano service to go back from public key'
      f' to password based network element authentication{ENDC}')
i = 5
while i > 0:
    try:
        print(f'{OKBLUE}{i}{ENDC}')
        time.sleep(1)
        i -= 1
    except KeyboardInterrupt:
        sys.exit()

EDIT_LIST = []
edit_data = {}
edit_data["edit-id"] = "edit1"
edit_data["operation"] = "delete"
edit_data["target"] = "/distkey:pubkey-dist"
EDIT_LIST.append(edit_data)
PATCH_DATA = {}
PATCH_DATA["patch-id"] = "delete-pubkey"
PATCH_DATA["edit"] = EDIT_LIST
INPUT_DATA = {"ietf-yang-patch:yang-patch": PATCH_DATA}

PATH = '/data?dry-run'
print(f"{BOLD}PATCH " + BASE_URL + PATH + f"{ENDC}")
print(f"{HEADER}" + json.dumps(INPUT_DATA, indent=2) + f"{ENDC}")
r = requests.patch(BASE_URL + PATH, json=INPUT_DATA, headers=headers_patch,
                   verify=False)
print(json.dumps(r.json(), indent=2))

dt_string = datetime.utcnow().isoformat()

PATH = '/data'
print(f"{BOLD}PATCH " + BASE_URL + PATH + f"{ENDC}")
print(f"{HEADER}" + json.dumps(INPUT_DATA, indent=2) + f"{ENDC}")
r = requests.patch(BASE_URL + PATH, json=INPUT_DATA, headers=headers_patch,
                   verify=False)
print(f'Status code: {r.status_code}\n')

print(f"\n{HEADER}##### Waiting for plan notifications for all deleted nano"
      f" service components to have reached the init state...{ENDC}")
PATH = '/streams/service-state-changes/json?start-time=' + dt_string
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
with requests.get(BASE_URL + PATH, headers=headers_stream, stream=True,
                  verify=False) as r:
    for notifs_str in r.iter_content(chunk_size=None, decode_unicode=True):
        notifs_str = notifs_str.replace('data: ', '')
        print(f"{HEADER}" + notifs_str + f"{ENDC}")
        notifications = notifs_str.split("\n\n")
        NREADY = 0
        for notif_str in notifications:
            if len(notif_str):
                notif = json.loads(notif_str)
                state = notif["ietf-restconf:notification"]\
                             ["tailf-ncs:plan-state-change"]\
                             ["state"]
                operation = notif["ietf-restconf:notification"]\
                                 ["tailf-ncs:plan-state-change"]\
                                 ["operation"]
                if ("tailf-ncs:init" in state and operation == "deleted"):
                    NREADY += 1
        if NREADY == NNES:
            break

print(f'\n{OKBLUE}###### Show the configuration added to NSO and network'
      f' elements\n{ENDC}')
PATH = '/data/tailf-ncs:devices/authgroups?fields=group(name;umap)'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

PATH = '/data/tailf-ncs:devices?fields=device(authgroup)'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

PATH = '/data/tailf-ncs:devices?fields=device/config/tailf-aaa:aaa/' +\
       'authentication/users/user(name;ssh-authkey:authkey)'
print(f"{BOLD}GET " + BASE_URL + PATH + f"{ENDC}")
r = requests.get(BASE_URL + PATH, headers=headers, verify=False)
print(r.text)

print(f"{OKGREEN}##### Done!{ENDC}")
