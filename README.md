Nano Service for Provisioning of SSH Public Key NETCONF Client Authentication
=============================================================================

This example is a system install production deployment variant of the NSO
example set local installation
[examples.ncs/getting-started/netsim-sshkey](https://github.com/NSO-developer/nso-examples/tree/main/getting-started/netsim-sshkey) example.

A sender can use a public key to encrypt a message or digital signature that
only the holder of the corresponding private key can decrypt. Each key pair is
unique, and the two keys work together. Using the private key, recipients can
prove they have it without sharing it. It's like proving you know a password
without showing someone the password.

A NETCONF SSH client, such as NSO's built-in NETCONF NED, uses its private and
public keys for authenticating the client with the server using a digital
signature and for the encryption part of setting up the Secure Shell (SSH)
connection.

This example automates the setup of SSH public key authentication using a nano
service (see the distkey.yang module for details). The nano service uses the
following steps in a plan that produces the `generated`, `distributed`, and
`configured` states:

1. Generates the NSO SSH client authentication key files using the OpenSSH
   `ssh-keygen` utility from a nano service side-effect action implemented
   in Python.

2. Distributes the public key to the netsim (ConfD) network elements to be
   stored as an authorized key using a Python service create() callback.

3. Configures NSO to use the public key for authentication with the netsim
   network elements using a Python service create() callback and service
   template.

4. Test the connection using the public key through a nano service side-effect
   executed by the NSO built-in `connect` action.

Upon deletion of the service instance, NSO restores the configuration. The only
delete step in the plan is the `generated` state side-effect action that
deletes the key files.

See the `distkey_app.py` for details on the Python application.

The netsim network elements implement a configuration subscriber Python
application triggered when a public key is added to or removed from the
`authkey` list. The application adds or removes the configured public key
to/from the user's `.ssh/authorized_keys` file, which the netsim (ConfD)
network element checks when authenticating public key authentication clients.
See the `ssh_authkey.py` application and the `distkey.yang` module for details.

Example Network Overview
------------------------
nso: NSO, the `distkey` service package, and the `ne` NETCONF NED package.
ex: netsim network element nodes are running ConfD and a Python configuration
    change subscriber.

      ----------  docker 0 default bridge  ----------
                                              |
                        +----------+          |
                        |   nso    |          |
                        +----------+          |
                              |               |
                              | .2            | .1
      -------------  ExampleNet bridge  -------------
            |                |                |
            |                |                |
                        192.168.23.0/16
            |                |                |
            | .99            | .98            | .97
         +----------+     +----------+     +----------+
         |   ex0    |     |   ex1    |     |    ex2   |
         +----------+     +----------+     +----------+

Prerequisites
-------------
- NSO_VERSION >= 6.5
- `nso-${NSO_VERSION}.linux.${NSO_ARCH}.installer.bin`
  or
  `nso-${NSO_VERSION}.container-image-prod.linux.${NSO_ARCH}.tar.gz` and
  `nso-${NSO_VERSION}.container-image-build.linux.${NSO_ARCH}.tar.gz`
- Docker installed

Running the Example
-------------------
First, either add the NSO installer binary into the directory of this `README`
file or load the NSO container image into the Docker image repository:

      cp /path/to/nso-${NSO_VERSION}.linux.${NSO_ARCH}.installer.bin /path/to/sshkey-deployment-example/

or

      docker load -i nso-${NSO_VERSION}.container-image-prod.linux.${NSO_ARCH}.tar.gz
      docker load -i nso-${NSO_VERSION}.container-image-dev.linux.${NSO_ARCH}.tar.gz

Then, change the version number NSO_VERSION variable in the `setup.sh` or
`setup_native.sh` file to match the NSO installer. For the `setup.sh`
variant, also change NSO_CONTAINER_VERSION to match container image
tar-ball.

To use the NSO container image, run the `setup.sh` script:

      ./setup.sh

When using the NSO installer binary, run the `setup_native.sh` script:

      ./setup_native.sh

Both scripts will follow the `nso` container output.

The `setup*.sh` scripts and Dockerfiles will set up the container nodes and
network as described above. The `nsoapp/run.sh` or `nsoapp/run_native.sh` shell
script will then generate the NSO host SSH keys, the NSO client SSH keys, and
the RESTCONF token. The showcase implements the NSO client applications in a
`showcase.sh` shell script that uses SSH to connect to the NSO CLI and the
`showcase_rc.sh` Python script, which uses the Python `request` module to
connect to NSO over RESTCONF.

Both the shell and Python scripts run the example according to the steps
described in the Getting Started documentation and configures the three network
element container nodes using the `distkey` nano service.

The above shell script uses the NSO CLI as the northbound interface, and a
Python script variant uses the NSO RESTCONF northbound interface and
notification events. Instead of polling for nano service state changes, as the
CLI script does, it uses the `service-state-changes` stream
`plan-notifications` to check when a nano service has reached a particular
state.

The `nsoapp/run*.sh`, `showcase.sh`, and `showcase_rc.py` scripts on the `nso`
container node performs the following steps to first setup NSO with SSH public
key and RESTCONF token authentication and then use NSO `distkey` nano service
to generate, distribute, and configure the network element nodes with SSH
public key authentication and then revert to password-based
authentication:

1. Reset and set up the example from the `nso` container. See the
   `nsoapp/run*.sh` script for details.

2. Run an NSO CLI-based demo. See the `showcase.sh` script for details

3. Generate keys, distribute the public key, and configure NSO for public key
   authentication with three network elements

4. Show the plan status

5. Show the configuration added to NSO and network elements

6. List the generated private and public keys

7. Delete the nano service to go back from public-key to password-based network
   element authentication

8. Show the restored configuration for password authentication

Implementation Details
----------------------
This demo uses Docker containers to set up a node running NSO plus NSO CLI +
RESTCONF clients and three nodes running netsim ConfD to simulate network
elements that NSO configure using a NETCONF SSH NED, as described by the NSO
Getting Started Guide chapter Developing and Deploying a Nano Service.

The steps for running the example described by the documentation are
implemented by the `setup.sh`, `Dockerfile`, `nsoapp/run.sh`,
`nsoapp/showcase.sh`, `nsoapp/showcase_rc.py`, `app/run.sh`, and `Makefile`
files.

When using the NSO installer, NSO is installed by and started in the context of
an `admin` user that belongs to the `ncsadmin` user group. For the NSO
production container, NSO is started in the contesxt of the `nso` user that
belongs to the `nso` user group, which is default for the NSO container.

On the `nso` container node, the NSO ncs, developer, audit, netconf, snmp,
and webui-access logs are configured in `$NCS_CONFIG_DIR/ncs.conf` and log
rotated periodically by a cron job.

The `ncs.conf` setting `/ncs-config/webui/server-name` is set by the
`NSO_HOST_NAME` vaiable and must be set to the host name used by a deployment
as `/ncs-config/webui/match-host-name` is set to `true`. See the setup.sh and
setup_native.sh files to change the NSO_HOST_NAME varable.

To make the demo self-contained, volumes shared between the Docker host and the
containers are not used. When using the NSO production container image, the
packages are loaded and `ncs.conf` is modified after NSO has initialized,
before northbound interfaces of NSO are enabled. See the NSO in containers
documentation for volume recommendations. Another option is to use a `FROM`
directive in a Dockerfile with the NSO container image as the parent image
and install packages and an `ncs.conf`. The `CMD ["/run-nso.sh"]` directive
can be used to start NSO.

NSO use Unix domain sockets for UID-based authenticated IPC communication.
Hence, only the user NSO run from and the `root` user can access NSO's IPC
port. For the containerized NSO variant the `nso` user and for the native
variant, the `admin` user.

The NSO CLI port 2024, NETCONF port 830, and RESTCONF WebUI HTTPS port 443 are
exposed to the Docker localhost. For `admin` user access, public key
authentication is required for the CLI and NETCONF interfaces, and token
authentication is required for RESTCONF. The read-only `oper` use password
authentication. See the `nsoapp/run*.sh` and `nsoapp/showcase*` scripts for
client authentication examples.

Further Reading
---------------
+ NSO Development Guide: Develop and Deploy a Nano Service
+ The [examples.ncs/getting-started/netsim-sshkey](https://github.com/NSO-developer/nso-examples/tree/main/getting-started/netsim-sshkey) example
+ NSO Administrator Guide: Containerized NSO
+ NSO Development Guide: Nano Services
+ NSO Administrator Guide: Deployment Example
+ The `setup.sh` or `setup_native.sh` and `nsoapp/run.sh` or
  `nsoapp/run_native.sh` scripts that setup the example
+ The `nsoapp/showcase.sh` and `nsoapp/showcase_rc.py` scripts that demo the
  nano service
+ The `app/run.sh` script that setup netsim ConfD and the config subscriber
+ The `tailf-ncs-plan.yang` and `tailf-ncs-services.yang` modules
