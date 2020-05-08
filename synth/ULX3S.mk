CHIPNAME=doomsoc_ulx3s
TOP=doomsoc_fpga
DOTF=$(HDL)/doomsoc_fpga/doomsoc_fpga_ulx3s.f

SYNTH_OPT=-abc9

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk


prog: bit
	ujprog $(CHIPNAME).bit

flash: bit
	ujprog -j flash $(CHIPNAME).bit
