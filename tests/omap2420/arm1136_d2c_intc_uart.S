/*
 * Gate D2c: ARM1136 OMAP2 UART1 RX loopback + bank2 IRQ72 + IRQ exception.
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors.
 * SPDX-License-Identifier: MIT
 *
 * Both UART TX output and input are through QEMU 16550 serial-mm MMIO.
 * ARM SYS_EXIT semihosting is used ONLY to terminate the test.
 * No Nokia firmware, clock/timer/PRCM/complete silicon claimed.
 */
    .syntax unified
    .arm
    .arch armv6
    .section .text.boot,"ax",%progbits
    .align 2
    .global _start

_start:
    ldr sp, =0x800ff000
    ldr r4, =0x4806a000              /* OMAP2 UART1 */
    ldr r5, =0x480fe000              /* OMAP2 INTC */
    ldr r6, =0x40200020              /* SRAM flag */

    /* Install ARM low exception IRQ vector at 0x18 (temporary vector RAM). */
    mov r0, #0x18
    ldr r1, =0xe51ff004              /* ldr pc, [pc, #-4] */
    str r1, [r0]
    ldr r1, =d2c_irq_handler
    str r1, [r0, #4]
    /* IRQ exception uses banked SP_irq; initialize it before unmasking. */
    mrs r0, cpsr
    bic r1, r0, #0x1f
    orr r1, r1, #0x12
    msr cpsr_c, r1
    ldr sp, =0x800fe000
    msr cpsr_c, r0

    mov r0, #0
    str r0, [r6]

    /* OMAP INTC: IRQ72 bank 2 bit 8, initially all masked. */
    ldr r0, [r5, #0xc4]               /* MIR2 */
    mvn r1, #0
    cmp r0, r1
    bne .Lfailed_intc

    /* 16550-compatible UART RX local loopback. IER bit0 enables RDI. */
    mov r0, #0x10
    strb r0, [r4, #0x10]              /* MCR_LOOP */
    mov r0, #1
    strb r0, [r4, #4]                 /* IER RDI */
    mov r0, #0x5a
    strb r0, [r4]                     /* TX into UART loopback RX FIFO */

    mov r8, #0
.Lwait_rx:
    ldrb r0, [r4, #0x14]              /* LSR.DR */
    tst r0, #1
    bne .Lgot_rx
    add r8, r8, #1
    ldr r0, =100000
    cmp r8, r0
    blt .Lwait_rx
    b .Lfailed_rx

.Lgot_rx:
    ldr r0, [r5, #0xc0]               /* INTC ITR2 raw IRQ72 */
    tst r0, #0x100
    beq .Lfailed_intc
    ldr r0, [r5, #0xd8]               /* INTC PENDING_IRQ2 */
    tst r0, #0x100
    bne .Lfailed_intc                /* still masked */

    mov r0, #0x100
    str r0, [r5, #0xc8]               /* INTC MIR_CLEAR2 bit8 */
    ldr r0, [r5, #0xc4]
    tst r0, #0x100
    bne .Lfailed_intc
    ldr r0, [r5, #0xd8]
    tst r0, #0x100
    beq .Lfailed_intc
    ldr r0, [r5, #0x40]               /* INTC SIR_IRQ */
    cmp r0, #72
    bne .Lfailed_intc

    /* Polling guest consumes the first RX byte. */
    ldrb r0, [r4]
    cmp r0, #0x5a
    bne .Lfailed_rx
    ldr r0, [r5, #0xd8]
    tst r0, #0x100
    bne .Lfailed_intc
    mov r0, #1
    str r0, [r5, #0x48]               /* INTC NEWIRQAGR */

    /* Now demonstrate actual ARM1136 IRQ exception entry to 0x18.
       CPU IRQ is initially disabled. Unmask before second UART RX. */
    mrs r0, cpsr
    bic r0, r0, #0x80
    msr cpsr_c, r0
    mov r0, #0x33
    strb r0, [r4]                     /* new loopback RX -> UART IRQ -> INTC */

    ldr r8, =150000
.Lwait_exception:
    ldr r0, [r6]
    cmp r0, #1
    beq .Lirq_pass
    subs r8, r8, #1
    bne .Lwait_exception
    b .Lfailed_exception

.Lirq_pass:
    /* Prevent further IRQs while configuring serial for terminal output. */
    mrs r0, cpsr
    orr r0, r0, #0x80
    msr cpsr_c, r0
    mov r0, #0
    strb r0, [r4, #4]                 /* Disable UART interrupt */
    strb r0, [r4, #0x10]              /* Disable UART loopback */
    mov r0, #0x100
    str r0, [r5, #0xcc]               /* Mask IRQ72 again */

    /* D2a memory + CPU ARMv6 regression. */
    ldr r0, =0x40200000
    ldr r1, =0x11223344
    str r1, [r0]
    ldr r2, [r0]
    cmp r1, r2
    bne .Lfailed_ram
    ldr r0, =0x4029fffc
    mvn r1, #0
    str r1, [r0]
    ldr r2, [r0]
    cmp r1, r2
    bne .Lfailed_ram
    ldr r0, =0x80040000
    ldr r1, =0x5a5aa5a5
    str r1, [r0]
    ldr r2, [r0]
    cmp r1, r2
    bne .Lfailed_ram
    ldr r0, =0x87fffffc
    ldr r1, =0x12345678
    str r1, [r0]
    ldr r2, [r0]
    cmp r1, r2
    bne .Lfailed_ram
    rev r2, r1
    ldr r3, =0x78563412
    cmp r2, r3
    bne .Lfailed_ram

    ldr r1, =pass_text
    bl uart_write0
    b exit_pass

.Lfailed_rx:
    mov r0, #0
    strb r0, [r4, #4]
    strb r0, [r4, #0x10]
    ldr r1, =fail_rx
    bl uart_write0
    b exit_fail
.Lfailed_intc:
    mov r0, #0
    strb r0, [r4, #4]
    strb r0, [r4, #0x10]
    ldr r1, =fail_intc
    bl uart_write0
    b exit_fail
.Lfailed_exception:
    mrs r0, cpsr
    orr r0, r0, #0x80
    msr cpsr_c, r0
    mov r0, #0
    strb r0, [r4, #4]
    strb r0, [r4, #0x10]
    ldr r1, =fail_exception
    bl uart_write0
    b exit_fail
.Lfailed_ram:
    ldr r1, =fail_ram
    bl uart_write0
    b exit_fail

/* Executes in IRQ mode using separately initialized SP_irq. */
d2c_irq_handler:
    stmdb sp!, {r0-r3, lr}
    ldr r0, =0x4806a000
    ldrb r1, [r0]                     /* Consume RX, deassert UART IRQ */
    cmp r1, #0x33
    bne .Lirq_bad
    ldr r0, =0x480fe048
    mov r1, #1
    str r1, [r0]                     /* INTC NEWIRQAGR */
    ldr r0, =0x40200020
    mov r1, #1
    str r1, [r0]                     /* Evidence of real IRQ exception */
    b .Lirq_return
.Lirq_bad:
    ldr r0, =0x40200020
    mov r1, #2
    str r1, [r0]
.Lirq_return:
    ldmia sp!, {r0-r3, lr}
    subs pc, lr, #4

uart_write0:
    ldrb r0, [r1], #1
    cmp r0, #0
    bxeq lr
    strb r0, [r4]                    /* UART1 THR MMIO -> -serial stdio */
    b uart_write0

exit_pass:
    mov r0, #0x18
    ldr r1, =0x20026                /* ARM semihosting for SYS_EXIT only */
    svc #0x123456
    b .
exit_fail:
    mov r0, #0x18
    ldr r1, =0x20023
    svc #0x123456
    b .

    .align 2
pass_text:
    .asciz "D2C_UART1_RX_LOOPBACK=PASS\nD2C_INTC_IRQ72_RAW_MASK_PENDING=PASS\nD2C_INTC_MIR_CLEAR_ACK=PASS\nD2C_ARM1136_CPU_IRQ_EXCEPTION=PASS\nD2C_D2A_MEMORY_ARMV6_REGRESSION=PASS\nD2C_OMAP2_CLOCK_TIMER=NOT_IMPLEMENTED\n"
fail_rx:
    .asciz "D2C_UART1_RX_LOOPBACK=FAIL\n"
fail_intc:
    .asciz "D2C_INTC_IRQ72_RAW_MASK_PENDING=FAIL\n"
fail_exception:
    .asciz "D2C_ARM1136_CPU_IRQ_EXCEPTION=FAIL\n"
fail_ram:
    .asciz "D2C_D2A_MEMORY_ARMV6_REGRESSION=FAIL\n"
