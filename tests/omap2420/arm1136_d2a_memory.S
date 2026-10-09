/*
 * ARMv6 memory test for minimal OMAP2420-style map, not Nokia firmware.
 * Output through semihosting SYS_WRITE0, NOT UART (deferred until Gate D2b).
 *
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors.
 * SPDX-License-Identifier: MIT
 */
    .syntax unified
    .arm
    .arch armv6
    .section .text.boot,"ax",%progbits
    .align 2
    .global _start
    .type _start, %function

_start:
    ldr sp, =0x800ff000
    ldr r0, =0x11223344
    ldr r1, =0x40200000
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lsram_failure

    ldr r1, =0x4029fffc
    mvn r0, #0
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lsram_failure

    ldr r1, =0x80040000
    ldr r0, =0x5a5aa5a5
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lsdram_failure

    ldr r1, =0x87fffffc
    ldr r0, =0x12345678
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lsdram_failure

    rev r6, r0
    ldr r7, =0x78563412
    cmp r6, r7
    bne .Lcpu_failure

    ldr r1, =success
    bl write0
    b .Lexit_success

.Lsram_failure:
    ldr r1, =sram_bad
    bl write0
    b .Lexit_failed
.Lsdram_failure:
    ldr r1, =sdram_bad
    bl write0
    b .Lexit_failed
.Lcpu_failure:
    ldr r1, =cpu_bad
    bl write0
    b .Lexit_failed

write0:
    mov r0, #4          /* Angel SYS_WRITE0: zero-terminated string */
    svc #0x123456
    bx lr

.Lexit_success:
    mov r0, #0x18      /* Angel SYS_EXIT */
    ldr r1, =0x20026  /* ADP_Stopped_ApplicationExit */
    svc #0x123456
    b .
.Lexit_failed:
    mov r0, #0x18
    ldr r1, =0x20023  /* ADP_Stopped_RunTimeError */
    svc #0x123456
    b .

    .align 2
success:
    .asciz "D2A_OMAP2420_SRAM=PASS\nD2A_OMAP2420_SDRAM=PASS\nD2A_ARM1136_REV=PASS\nD2A_BOOT_ELF=PASS\nD2A_UART=NOT_IMPLEMENTED\n"
sram_bad:
    .asciz "D2A_OMAP2420_SRAM=FAIL\n"
sdram_bad:
    .asciz "D2A_OMAP2420_SDRAM=FAIL\n"
cpu_bad:
    .asciz "D2A_ARM1136_REV=FAIL\n"
    .size _start, . - _start
