/* Nokia UTM OMAP2420 diagnostic v10.1 iPhone UART-only smoke test.
 * Bare-metal ARM1136 (ARMv6). Emits one UART1 marker and loops forever.
 * Deliberately never calls semihosting SYS_EXIT, which calls C exit() inside
 * the embedded QEMU process and may close the host iOS application.
 */
.syntax unified
.cpu arm1136j-s
.arm
.global _start
.section .text,"ax",%progbits
_start:
    ldr r4, =0x4806A000
    adr r5, marker
print_next:
    ldrb r0, [r5], #1
    cmp r0, #0
    beq guest_idle
wait_tx_ready:
    ldrb r1, [r4, #20]
    tst r1, #0x20
    beq wait_tx_ready
    strb r0, [r4]
    b print_next
guest_idle:
    b guest_idle
    .balign 4
marker:
    .asciz "OMAP2420_ARM1136_UART_NOEXIT=PASS\r\n"
