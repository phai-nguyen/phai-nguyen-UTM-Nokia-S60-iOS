/*
 * Gate D2b ARM1136 UART1 real serial-MMIO + OMAP vendor registers.
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors
 * SPDX-License-Identifier: MIT
 *
 * Real console output only via ARMv6 STRB to OMAP2420 UART1 THR 0x4806a000.
 * ARM semihosting is ONLY used for terminating QEMU, not for any output.
 * This is not Nokia firmware or a full OMAP2420 boot.
 */
    .syntax unified
    .arm
    .arch armv6
    .section .text.boot,"ax",%progbits
    .align 2
    .global _start
    .type _start,%function

_start:
    ldr sp, =0x800ff000
    ldr r4, =0x4806a000          /* UART1 base; 16550 THR at +0 */

    /* Check QEMU serial-mm UART LSR register 5, spacing 4 bytes. */
    ldrb r3, [r4, #0x14]         /* UART_LSR */
    tst r3, #0x20                /* UART_LSR_THRE */
    beq .Lbad_core

    /* Validate vendor-specific OMAP2 registers, not just re-based i.MX31. */
    ldrb r3, [r4, #0x50]         /* UART_MVR */
    cmp r3, #0x30
    bne .Lbad_vendor
    ldrb r3, [r4, #0x58]         /* SYSS */
    cmp r3, #1
    bne .Lbad_vendor
    ldrb r3, [r4, #0x5c]         /* WER reset default */
    cmp r3, #0x3f
    bne .Lbad_vendor

    mov r3, #0x21
    strb r3, [r4, #0x5c]         /* WER: writable */
    ldrb r3, [r4, #0x5c]
    cmp r3, #0x21
    bne .Lbad_vendor

    mov r3, #0x5a
    strb r3, [r4, #0x40]         /* SCR: writable */
    ldrb r3, [r4, #0x40]
    cmp r3, #0x5a
    bne .Lbad_vendor

    mov r3, #2
    strb r3, [r4, #0x54]         /* SYSC soft-reset */
    ldrb r3, [r4, #0x5c]
    cmp r3, #0x3f
    bne .Lbad_vendor
    ldrb r3, [r4, #0x58]
    cmp r3, #1
    bne .Lbad_vendor

    /* Carry forward Gate D2a SRAM / SDRAM / ARMv6 execution proof. */
    ldr r1, =0x40200000
    ldr r0, =0x11223344
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lbad_ram

    ldr r1, =0x4029fffc
    mvn r0, #0
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lbad_ram

    ldr r1, =0x80040000
    ldr r0, =0x5a5aa5a5
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lbad_ram

    ldr r1, =0x87fffffc
    ldr r0, =0x12345678
    str r0, [r1]
    ldr r2, [r1]
    cmp r2, r0
    bne .Lbad_ram

    rev r6, r0
    ldr r7, =0x78563412
    cmp r6, r7
    bne .Lbad_cpu

    /* All success markers are emitted ONLY via OMAP UART MMIO TX. */
    ldr r1, =success
    bl .Luart_write0
    b .Lexit_good

.Lbad_core:
    ldr r1, =bad_core
    bl .Luart_write0
    b .Lexit_bad
.Lbad_vendor:
    ldr r1, =bad_vendor
    bl .Luart_write0
    b .Lexit_bad
.Lbad_ram:
    ldr r1, =bad_ram
    bl .Luart_write0
    b .Lexit_bad
.Lbad_cpu:
    ldr r1, =bad_cpu
    bl .Luart_write0
    b .Lexit_bad

.Luart_write0:
    ldrb r0, [r1], #1
    cmp r0, #0
    bxeq lr
    strb r0, [r4]               /* Real QEMU UART1 THR, NOT semihosting */
    b .Luart_write0

.Lexit_good:
    mov r0, #0x18
    ldr r1, =0x20026           /* ARM semihosting SYS_EXIT / success */
    svc #0x123456
    b .
.Lexit_bad:
    mov r0, #0x18
    ldr r1, =0x20023           /* ARM semihosting SYS_EXIT / failure */
    svc #0x123456
    b .

    .align 2
success:
    .asciz "D2B_UART1_16550_TX_MMIO=PASS\nD2B_UART1_VENDOR_REGS=PASS\nD2B_SRAM_SDRAM_REGRESSION=PASS\nD2B_ARM1136_ARMV6_REV=PASS\nD2B_UART1_RX=NOT_TESTED\nD2B_OMAP2_INTC_IRQ=NOT_IMPLEMENTED\n"
bad_core:
    .asciz "D2B_UART1_16550_TX_MMIO=FAIL\n"
bad_vendor:
    .asciz "D2B_UART1_VENDOR_REGS=FAIL\n"
bad_ram:
    .asciz "D2B_SRAM_SDRAM_REGRESSION=FAIL\n"
bad_cpu:
    .asciz "D2B_ARM1136_ARMV6_REV=FAIL\n"
    .size _start, . - _start
