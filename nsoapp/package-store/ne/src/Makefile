all: fxs
.PHONY: all

# Include standard NCS examples build definitions and rules
include $(NCS_DIR)/src/ncs/build/include.ncs.mk

SRC = $(wildcard yang/*.yang)
FXS = $(SRC:yang/%.yang=ncsc-out/modules/fxs/%.fxs)
DIRS =  ncsc-out ../load-dir
NCSC_EXTRA_FLAGS += --ncs-skip-template
NED_ID_ARG = $(shell [ -x ${NCS_DIR}/support/ned-ncs-ned-id-arg ] && \
               ${NCS_DIR}/support/ned-ncs-ned-id-arg package-meta-data.xml.in)

YANGPATH += $(NCS_DIR)/netsim/confd/src/confd/yang
NCSCPATH   = $(YANGPATH:%=--yangpath %)

fxs: $(DIRS) ../package-meta-data.xml ncsc-out/.done
.PHONY: fxs

$(DIRS):
	mkdir -p $@

../package-meta-data.xml: package-meta-data.xml.in
	rm -rf $@
	if [ -x ${NCS_DIR}/support/ned-make-package-meta-data ]; then \
	    ${NCS_DIR}/support/ned-make-package-meta-data $<;         \
	else                                                          \
	    grep -v 'to be replaced by build' $< > $@;                \
	fi
	chmod -w $@

ncsc-out/.done:	$(SRC)
	$(NCSC) --ncs-compile-bundle yang                   \
	    --ncs-device-dir ncsc-out                        \
	    --fail-on-warnings                              \
	                            \
	                                \
	    --ncs-device-type netconf                        \
	    $(NCSCPATH)                                     \
	    $(NED_ID_ARG)                                   \
	    $(NCSC_EXTRA_FLAGS)
	cp ncsc-out/modules/fxs/*.fxs ../load-dir
	for f in `echo ../load-dir/*.fxs`; do \
	   true; \
	done
	touch ncsc-out/.done

clean:
	rm -rf $(DIRS) ../package-meta-data.xml
.PHONY: clean