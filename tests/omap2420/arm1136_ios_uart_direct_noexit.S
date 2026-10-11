/* iPhone UART smoke variant: no UART LSR polling, no semihosted SYS_EXIT.
 * Matches the raw THR byte-write approach in host-PASS Gate D2d UART routine.
 * Machine: omap2420-timerdiag, CPU: arm1136, 128 MiB, kernel ELF.
 * The banner means CPU loaded AND an MMIO byte was sent to UART1,
 * not that PRCM/GPTimer/INTC passed. Stop the VM manually.
 */
.syntax unified
.arch armv6
.arm
.section .text.boot,"ax",%progbits
.align 2
.global _start
_start:
    ldr sp, =0x800ff000
    ldr r4, =0x4806a000
    ldr r1, =message
print_uart:
    ldrb r0, [r1], #1
    cmp r0, #0
    beq idle
    strb r0, [r4]
    b print_uart
idle:
    b idle
.align 2
message:
    .asciz "OMAP2420_ARM1136_UART_DIRECT_NOEXIT=PASS\n"
