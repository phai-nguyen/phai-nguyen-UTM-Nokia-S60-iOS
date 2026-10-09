/* Diagnostic ELF loaded in OMAP2420-style SDRAM. No ROM/firmware. */
ENTRY(_start)
SECTIONS {
  . = 0x80010000;
  .text : { *(.text.boot) *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  .bss (NOLOAD) : { *(.bss*) *(COMMON) }
  /DISCARD/ : { *(.note*) *(.comment*) *(.ARM.attributes) }
}
