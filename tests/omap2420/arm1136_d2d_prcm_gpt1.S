/*
 * Gate D2d ARM1136: PRCM GPTimer1 clock gate, overflow IRQ37 to CPU.
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors
 * SPDX-License-Identifier: MIT
 *
 * UART console is real QEMU serial-mm MMIO, not semihosting. SYS_EXIT only.
 * No full OMAP clock tree or Nokia firmware.
 */
    .syntax unified
    .arm
    .arch armv6
    .section .text.boot,"ax",%progbits
    .align 2
    .global _start
_start:
    ldr sp, =0x800ff000
    ldr r4, =0x4806a000       /* OMAP2 UART1 MMIO */
    ldr r5, =0x480fe000       /* INTC */
    ldr r6, =0x40200040       /* SRAM IRQ flag */
    ldr r7, =0x48028000       /* GPTimer1 */
    ldr r9, =0x48008000       /* PRCM */

    /* Real IRQ handler low vector: one word indirection at 0x18. */
    mov r0, #0x18
    ldr r1, =0xe51ff004      /* ldr pc, [pc, #-4] */
    str r1, [r0]
    ldr r1, =timer_irq
    str r1, [r0, #4]
    mrs r0, cpsr
    bic r1, r0, #0x1f
    orr r1, r1, #0x12        /* switch to IRQ mode */
    msr cpsr_c, r1
    ldr sp, =0x800fe000
    msr cpsr_c, r0

    mov r0, #0
    str r0, [r6]

    ldr r0, [r7, #0x00]      /* GPT TIDR */
    cmp r0, #0x21
    bne fail_reset
    ldr r0, [r7, #0x14]      /* TISTAT RESETDONE */
    cmp r0, #1
    bne fail_reset
    ldr r0, [r9, #0x400]    /* PRCM FCLKEN_WKUP = gated initially */
    cmp r0, #0
    bne fail_clock
    ldr r0, [r9, #0x410]    /* PRCM ICLKEN_WKUP = gated initially */
    cmp r0, #0
    bne fail_clock
    ldr r0, [r5, #0xa4]     /* MIR1 reset masks IRQ37 */
    mvn r1, #0
    cmp r0, r1
    bne fail_intc

    mov r0, #2
    str r0, [r7, #0x1c]     /* TIER enable overflow IRQ */
    mov r0, #0
    str r0, [r7, #0x2c]     /* TLDR = 0 */
    ldr r0, =0xfffffffc
    str r0, [r7, #0x28]     /* TCRR start close to overflow */
    mov r0, #1
    str r0, [r7, #0x24]     /* TCLR ST, one-shot */

    /* Clock disabled => no timer count and no IRQ despite ST=1. */
    ldr r3, =1000
.Lgated_spin:
    subs r3, r3, #1
    bne .Lgated_spin
    ldr r0, [r7, #0x28]
    ldr r1, =0xfffffffc
    cmp r0, r1
    bne fail_clock
    ldr r0, [r7, #0x18]
    cmp r0, #0
    bne fail_clock

    mov r0, #1
    str r0, [r9, #0x400]    /* PRCM CM_FCLKEN_WKUP bit 0 */
    str r0, [r9, #0x410]    /* PRCM CM_ICLKEN_WKUP bit 0 */
    ldr r0, [r9, #0x400]
    cmp r0, #1
    bne fail_clock
    ldr r0, [r9, #0x410]
    cmp r0, #1
    bne fail_clock

    /* IRQ37 is masked, wait for timer overflow on virtual clock. */
    ldr r3, =200000
.Lwait_overflow:
    ldr r0, [r7, #0x18]     /* GPT TISR */
    tst r0, #2
    bne .Lgot_overflow
    subs r3, r3, #1
    bne .Lwait_overflow
    b fail_timer

.Lgot_overflow:
    ldr r0, [r7, #0x24]     /* one-shot TCLR.ST cleared on overflow */
    tst r0, #1
    bne fail_timer
    ldr r0, [r5, #0xa0]     /* INTC ITR1 bank1 bit 5 (IRQ37) */
    tst r0, #0x20
    beq fail_intc
    ldr r0, [r5, #0xb8]     /* PENDING_IRQ1 masked */
    tst r0, #0x20
    bne fail_intc

    mov r0, #0x20
    str r0, [r5, #0xa8]     /* MIR_CLEAR1 unmask IRQ37 */
    ldr r0, [r5, #0xb8]
    tst r0, #0x20
    beq fail_intc
    ldr r0, [r5, #0x40]     /* SIR_IRQ */
    cmp r0, #37
    bne fail_intc

    /* Unmask CPU IRQ: real exception vector 0x18 must execute handler. */
    mrs r0, cpsr
    bic r0, r0, #0x80
    msr cpsr_c, r0
    ldr r3, =100000
.Lwait_irq:
    ldr r0, [r6]
    cmp r0, #1
    beq .Lirq_ok
    subs r3, r3, #1
    bne .Lwait_irq
    b fail_exception

.Lirq_ok:
    mrs r0, cpsr
    orr r0, r0, #0x80
    msr cpsr_c, r0
    ldr r0, [r5, #0xb8]     /* IRQ37 must be deasserted */
    tst r0, #0x20
    bne fail_intc
    ldr r0, [r7, #0x18]     /* TISR overflow cleared by handler */
    tst r0, #2
    bne fail_intc

    /* Soft reset timer must clear counter/control/status and IRQ enable. */
    ldr r0, =0xdeadbeef
    str r0, [r7, #0x28]
    mov r0, #2
    str r0, [r7, #0x10]     /* TIOCP_CFG.SOFTRESET */
    ldr r0, [r7, #0x28]
    cmp r0, #0
    bne fail_reset
    ldr r0, [r7, #0x1c]
    cmp r0, #0
    bne fail_reset
    ldr r0, [r7, #0x18]
    cmp r0, #0
    bne fail_reset

    /* Clock gates should be writable back to OFF. */
    mov r0, #0
    str r0, [r9, #0x400]
    str r0, [r9, #0x410]
    ldr r0, [r9, #0x400]
    cmp r0, #0
    bne fail_clock

    /* Keep D2a ARMv6 SRAM/SDRAM checks within D2d payload. */
    ldr r0, =0x40200000
    ldr r1, =0x11223344
    str r1, [r0]
    ldr r2, [r0]
    cmp r1, r2
    bne fail_memory
    ldr r0, =0x80040000
    ldr r1, =0x12345678
    str r1, [r0]
    ldr r2, [r0]
    cmp r1, r2
    bne fail_memory
    rev r2, r1
    ldr r3, =0x78563412
    cmp r2, r3
    bne fail_memory

    ldr r1, =pass_text
    bl write_uart
    b exit_pass

/* Handler is entered in real ARM IRQ mode, not a function call. */
timer_irq:
    stmdb sp!, {r0-r3, lr}
    ldr r0, =0x480fe040    /* SIR_IRQ */
    ldr r1, [r0]
    cmp r1, #37
    bne .Lbad_vector
    ldr r0, =0x48028018    /* GPT TISR */
    ldr r1, [r0]
    tst r1, #2
    beq .Lbad_vector
    mov r1, #2
    str r1, [r0]          /* TISR W1C deassert device IRQ */
    ldr r0, =0x480fe048  /* INTC CONTROL */
    mov r1, #1
    str r1, [r0]          /* NEWIRQAGR */
    ldr r0, =0x40200040
    mov r1, #1
    str r1, [r0]
    b .Lvector_done
.Lbad_vector:
    ldr r0, =0x40200040
    mov r1, #2
    str r1, [r0]
.Lvector_done:
    ldmia sp!, {r0-r3, lr}
    subs pc, lr, #4

fail_clock:
    ldr r1, =fail_clock_text
    b report_fail
fail_timer:
    ldr r1, =fail_timer_text
    b report_fail
fail_intc:
    ldr r1, =fail_intc_text
    b report_fail
fail_exception:
    ldr r1, =fail_exception_text
    b report_fail
fail_reset:
    ldr r1, =fail_reset_text
    b report_fail
fail_memory:
    ldr r1, =fail_memory_text
report_fail:
    mrs r0, cpsr
    orr r0, r0, #0x80
    msr cpsr_c, r0
    bl write_uart
    b exit_fail

write_uart:
    ldrb r0, [r1], #1
    cmp r0, #0
    bxeq lr
    strb r0, [r4]         /* actual UART THR at OMAP2 address */
    b write_uart

exit_pass:
    mov r0, #0x18
    ldr r1, =0x20026
    svc #0x123456        /* SYS_EXIT only */
    b .
exit_fail:
    mov r0, #0x18
    ldr r1, =0x20023
    svc #0x123456
    b .

    .align 2
pass_text:
    .asciz "D2D_PRCM_GPT1_CLOCK_GATING=PASS\nD2D_GPT1_OVERFLOW_TISR_TIER=PASS\nD2D_GPT1_INTC_IRQ37_PENDING_MASK_ACK=PASS\nD2D_ARM1136_GPT1_IRQ_EXCEPTION=PASS\nD2D_GPT1_SOFTRESET=PASS\nD2D_D2A_ARMV6_MEMORY=PASS\nD2D_FULL_OMAP_CLOCK_TREE=NOT_IMPLEMENTED\n"
fail_clock_text:
    .asciz "D2D_PRCM_GPT1_CLOCK_GATING=FAIL\n"
fail_timer_text:
    .asciz "D2D_GPT1_OVERFLOW_TISR_TIER=FAIL\n"
fail_intc_text:
    .asciz "D2D_GPT1_INTC_IRQ37_PENDING_MASK_ACK=FAIL\n"
fail_exception_text:
    .asciz "D2D_ARM1136_GPT1_IRQ_EXCEPTION=FAIL\n"
fail_reset_text:
    .asciz "D2D_GPT1_SOFTRESET=FAIL\n"
fail_memory_text:
    .asciz "D2D_D2A_ARMV6_MEMORY=FAIL\n"
