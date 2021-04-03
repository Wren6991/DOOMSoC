TEST?=$(notdir $(PWD))

DOTF=../tb.f
SRCS=init.S $(TEST).c

INCDIRS=../include
LDSCRIPT=../memmap_2nd.ld
# Disassemble all sections
DISASSEMBLE=-D

include $(SCRIPTS)/sim.mk

compile:
	make -C $(SOFTWARE)/apps/bootloader all
	cp $(SOFTWARE)/apps/bootloader/bootloader32.hex bootram_init.hex
	make -C $(SOFTWARE)/build APPNAME=$(TEST) LDSCRIPT=$(LDSCRIPT)
	cp $(SOFTWARE)/build/$(TEST)8.hex sdram_init8.hex
	$(SCRIPTS)/vhexwidth sdram_init8.hex -w 32 -b 0x20000000 -o sdram_init.hex

test:
	$(MAKE) sim TEST=$(TEST) > sim.log
	./test_script sim.log

clean::
	rm -f *ram_init.hex
	make -C $(SOFTWARE)/apps/bootloader clean
	make -C $(SOFTWARE)/build APPNAME=$(TEST) clean
	rm -f sim.log
