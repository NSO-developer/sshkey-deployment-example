"""A subscriber that sync a list of authorized keys with a file used by the
netsim ConfD SSH server to authenticate users using public keys.

See the README file for more information
"""
import logging
import os
import ncs as tm

confd_port = 0


class MyIter(object):
    def __init__(self, log, name='authkey'):
        self.log = log
        self.name = name

    def iterate(self, kp, op, oldv, newv, state):
        """Sync the users authorized keys file with configuration changes to
        the authkey list in CDB"""
        self.log.info(f'iterate kp={kp} op={op} oldv={oldv} newv={newv}')
        app_name = os.getenv('APP_NAME')
        if op is tm.MOP_CREATED:
            self.log.info(f'create user={kp[2][0]} pubkey_data={kp[0][0]}')
            with open(f'/{app_name}/homes/{kp[2][0]}/.ssh/authorized_keys',
                      'a+') as f:
                f.write(f"{kp[0][0]}\n")
        elif op is tm.MOP_DELETED:
            self.log.info(f'delete user={kp[2][0]} pubkey_data={kp[0][0]}')
            with open(f'/{app_name}/homes/{kp[2][0]}/.ssh/authorized_keys',
                      'r') as f:
                lines = f.readlines()
            with open(f'/{app_name}/homes/{kp[2][0]}/.ssh/authorized_keys',
                      'w') as f:
                for line in lines:
                    if line != kp[0][0] and line != "\n":
                        f.write(line)
        return tm.ITER_CONTINUE


def main(port):
    """Register a CDB subscriber to be notified of config changes under the
    authkey list"""
    global confd_port
    log = tm.log.Log(logging.getLogger(__name__))
    confd_port = port
    sub = tm.cdb.Subscriber(log=log, port=port)
    sub.register('/aaa:aaa/aaa:authentication/aaa:users/aaa:user/sa:authkey',
                 MyIter(log))
    sub.start()


if __name__ == '__main__':
    """Set up logging and start the application"""
    import sys
    logging.basicConfig(level=logging.INFO, filename='logs/ssh-authkey.log',
                        format='%(asctime)s %(levelname)-8s %(message)s')
    main(int(sys.argv[1]))
