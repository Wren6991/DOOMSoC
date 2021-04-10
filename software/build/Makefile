SRC_DIR=../src
SRCS=$(SRC_DIR)/init.S $(SRC_DIR)/$(APPNAME).c
INCDIRS=../include
LDSCRIPT=../memmap_2nd.ld

MARCH=rv32im
CCFLAGS=-O
# Disassemble all sections
DISASSEMBLE=-D

include $(SCRIPTS)/software.mk
