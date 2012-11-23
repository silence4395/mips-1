SLD_PATH = sldbin/contest.sldbin

targets:
	@echo min-rt-new.ml

%.test: %.ans %.sim
	diff $*.ans $*.sim

%.test_core: %.ans %.core
	diff $*.ans $*.core

%.ans: %.sim
	cp $*.sim $*.ans

include ../Makefile.in

%.s: %.ml
	cat $(LIB_ML) globals.ml $*.ml > /tmp/`basename $*`.ml
	$(MIN_CAML) $(OPTION) /tmp/`basename $*`
	$(LINKER) $(LIB_ASM) /tmp/`basename $*`.s ${abspath $*.s}

%.sim: %.bin
	$(SIMULATOR) -f $(SLD_PATH) $*.bin > $*.sim