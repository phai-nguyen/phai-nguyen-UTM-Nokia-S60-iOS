/*
 * ARM1136 (ARMv6) CPU instruction + MMIO UART diagnostic for QEMU 'kzm'.
 *
 * Copyright 2026 UTM Nokia ARM32 compatibility contributors
 * SPDX-License-Identifier: MIT
 *
 * NOT Nokia firmware, NOT OMAP2420, NOT an N95 board. The KZM test platform
 * uses Freescale i.MX31 and an ARM1136 CPU supported by QEMU 10.
 *
 * Verified source locations:
 *   utmapp/qemu@v10.0.12-utm/hw/arm/kzm.c
 *   utmapp/qemu@v10.0.12-utm/include/hw/arm/fsl-imx31.h
 *   utmapp/qemu@v10.0.12-utm/hw/char/imx_serial.c
 * UART1 MMIO base 0x43f90000, UTXD offset 0x40.
 */
    .syntax unified
    .arm
    .arch armv6
    .section .text.boot,"ax",%progbits
    .align 2
    .global _start
    .type _start, %function

_start:
    ldr sp, =0x80080000     /* KZM SDRAM */
    ldr r4, =0x43f90040     /* KZM's i.MX31 UART1 UTXD MMIO */
    ldr r1, =hello
    bl uart_write0

    /* REV is an ARMv6 instruction. Validate the executed result. */
    ldr r6, =0x12345678
    rev r7, r6
    ldr r8, =0x78563412
    cmp r7, r8
    bne .Lfailed
    ldr r1, =success
    bl uart_write0

    /* Angel semihosting SYS_EXIT / ADP_Stopped_ApplicationExit.
       This exits the QEMU process if semihosting is enabled. */
    mov r0, #0x18
    ldr r1, =0x20026
    svc #0x123456
.Lhalt:
    b .Lhalt

.Lfailed:
    ldr r1, =failure
    bl uart_write0
    mov r0, #0x18
    ldr r1, =0x20023
    svc #0x123456
    b .Lhalt

uart_write0:
    ldrb r0, [r1], #1
    cmp r0, #0
    bxeq lr
    str r0, [r4]           /* QEMU imx_serial UTXD write at base + 0x40 */
    b uart_write0

    .align 2
hello:
    .asciz "ARM1136_KZM_UART_MMIO=PASS\n"
success:
    .asciz "ARM1136_ARMV6_REV_INSTRUCTION=PASS\nARM1136_BAREMETAL_BOOT=PASS\n"
failure:
    .asciz "ARM1136_ARMV6_REV_INSTRUCTION=FAIL\n"
    .size _start, . - _start
