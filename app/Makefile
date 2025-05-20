FLAGS = --yangpath ${CONFD_DIR}/src/confd/aaa

# Install the netsim ConfD application and compile the device YANG model and
# the clispec to remove the commands from the CLI that access the file system
all: install ssh-authkey.fxs command-c.ccl

%.fxs:  ./%.yang
	 $(CONFD_DIR)/bin/confdc $(FLAGS) -c -o $@  $<

%.ccl: ./%.cli
	 $(CONFD_DIR)/bin/confdc -c -o $@  $<

install:
	mkdir cdb 2>/dev/null || true
	mkdir logs 2>/dev/null || true
	mkdir -p /${APP_NAME}/homes/admin/.ssh 2>/dev/null || true
	mkdir -p /${APP_NAME}/homes/oper/.ssh 2>/dev/null || true
	cp -af $(CONFD_DIR)/etc/confd/ssh ./
	cp -af $(CONFD_DIR)/var/confd/cdb ./
	cp ./aaa_init.xml ./cdb/aaa_init.xml
	sed -i.bak -e "s|_PATH_|/${APP_NAME}/|g" ./cdb/aaa_init.xml
	sed -i.bak -e "s|_NAME_|${EX_NAME}/|g" ./confd.conf

clean:
	@rm -rf *.fxs *.ccl cdb logs ssh tailf-aaa.yang
