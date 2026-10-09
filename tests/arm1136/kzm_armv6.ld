/* ARM1136 KZM diagnostic ELF at SDRAM: this is NOT Nokia boot ROM. */
ENTRY(_start)
SECTIONS {
  . = 0x80010000;
  .text : { *(.text.boot) *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  .bss (NOLOAD) : { *(.bss*) *(COMMON) }
  /DISCARD/ : { *(.note*) *(.comment*) *(.ARM.attributes) }
}
