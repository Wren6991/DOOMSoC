CHIPNAME=doomsoc_ulx3s
TOP=doomsoc_fpga
DOTF=$(HDL)/doomsoc_fpga/doomsoc_fpga_ulx3s.f
BOOTAPP=doomsoc_bootloader

SYNTH_OPT=-abc9

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) CCFLAGS="-Os"
	cp $(SOFTWARE)/build/$(BOOTAPP)8.hex bootram_init8.hex
	$(SCRIPTS)/vhexwidth bootram_init8.hex -w 32 -b 0x20080000 -o bootram_init32.hex

clean::
	make -C $(SOFTWARE)/build APPNAME=$(BOOTAPP) clean
	rm -f bootram_init*.hex

prog: bit
	ujprog $(CHIPNAME).bit

flash: bit
	ujprog -j flash $(CHIPNAME).bit
