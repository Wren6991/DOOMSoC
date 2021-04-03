/* Script for -z combreloc: combine and sort reloc sections */
/* Copyright (C) 2014-2017 Free Software Foundation, Inc.
   Copying and distribution of this script, with or without modification,
   are permitted in any medium without royalty provided the copyright
   notice and this notice are preserved.  */

/* Bootloader linker script for DOOMSoC */

MEMORY
  {
    ICACHE (x)  : ORIGIN = 0x0,   LENGTH = 2K
    DCACHE (wx) : ORIGIN = 0x800, LENGTH = 2K
  }

OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv",
        "elf32-littleriscv")
OUTPUT_ARCH(riscv)
SEARCH_DIR("/opt/riscv/riscv32-unknown-elf/lib");
SECTIONS
{
  PROVIDE (__executable_start = ORIGIN(ICACHE)); . = ORIGIN(ICACHE);
  .text           :
  {
    KEEP (*(SORT_NONE(.vectors)))
    *(.text .text.*)
  } > ICACHE
  PROVIDE (__etext = .);

  . = ORIGIN(DCACHE);
  __data_start = .;
  .rodata         : { 
    *(.rodata .rodata.*)
    *(.rodata1)
  } > DCACHE
  .data           :
  {
    __global_pointer$ = . + 0x800;
    __global_pointer = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata .srodata.*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    *(.sdata2 .sdata2.* .gnu.linkonce.s2.*)
    *(.data .data.* .gnu.linkonce.d.*)
    SORT(CONSTRUCTORS)
    *(.data1)
  } > DCACHE
  _edata = .; PROVIDE (edata = .);
  __data_end = .;

  . = .;
  __bss_start = .;
  .bss            :
  {
   *(.dynsbss)
   *(.sbss .sbss.* .gnu.linkonce.sb.*)
   *(.scommon)
   *(.dynbss)
   *(.bss .bss.* .gnu.linkonce.b.*)
    *(.sbss2 .sbss2.* .gnu.linkonce.sb2.*)
   *(COMMON)
   /* Align here to ensure that the .bss section occupies space up to
      _end.  Align after .bss to ensure correct alignment even if the
      .bss section disappears because there are no input sections.
      FIXME: Why do we need it? When there is no .bss section, we don't
      pad the .data section.  */
   . = ALIGN(. != 0 ? 32 / 8 : 1);
  }
  . = ALIGN(32 / 8);
  __bss_end = .;

  . = ALIGN(32 / 8);
  . = SEGMENT_START("ldata-segment", .);
  . = ALIGN(32 / 8);
  _end = .; PROVIDE (end = .);
  __stack_top = ORIGIN(DCACHE) + LENGTH(DCACHE);
}


