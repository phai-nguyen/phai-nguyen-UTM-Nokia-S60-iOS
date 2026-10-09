/*
 * Gate D2b: EARLY OMAP2420 MMIO UART1 TX + register diagnostic for QEMU10.
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * THIS IS NOT A NOKIA N95 / FULL OMAP2420 MACHINE.
 *
 * Memory map comes from QEMU upstream v9.1 OMAP2 reference:
 *   SRAM 0x40200000, SDRAM 0x80000000, UART1 0x4806a000.
 * Standard 16550 TX/RX/FIFO register engine comes from QEMU v10's
 * serial-mm and serial devices, not from semihosting or i.MX31 UART.
 * Vendor registers are explicitly modelled at UART1 + 0x20..+0x60.
 * The UART IRQ terminates in a diagnostic sink; OMAP2 INTC is Gate D2c.
 * OMAP clocks, DMA, other UARTs, L4 interconnect are NOT implemented.
 */
#include "qemu/osdep.h"
#include "qapi/error.h"
#include "hw/arm/boot.h"
#include "hw/boards.h"
#include "hw/char/serial-mm.h"
#include "hw/irq.h"
#include "hw/qdev-core.h"
#include "exec/address-spaces.h"
#include "qemu/error-report.h"
#include "qemu/log.h"
#include "qemu/units.h"
#include "system/qtest.h"
#include "system/system.h"
#include "target/arm/cpu.h"
#include "target/arm/cpu-qom.h"

#define D2B_SRAM_BASE       0x40200000ULL
#define D2B_SRAM_SIZE       0x000A0000ULL
#define D2B_SDRAM_BASE      0x80000000ULL
#define D2B_SDRAM_MAX       (128 * MiB)
#define D2B_UART1_BASE      0x4806A000ULL
#define D2B_UART1_VENDOR    0x20
#define D2B_UART1_VENDOR_SZ 0x44

typedef struct D2BUartVendor {
    MemoryRegion mmio;
    uint8_t mdr1;
    uint8_t mdr2;
    uint8_t scr;
    uint8_t eblr;
    uint8_t sysc;
    uint8_t wer;
    uint8_t cfps;
    unsigned int diagnostic_irq_transitions;
    int last_irq_level;
} D2BUartVendor;

typedef struct D2BEarlyMachine {
    MemoryRegion sram;
    D2BUartVendor uart;
    struct arm_boot_info boot;
} D2BEarlyMachine;

static void d2b_vendor_reset(D2BUartVendor *s)
{
    s->mdr1 = 0;
    s->mdr2 = 0;
    s->scr = 0;
    s->eblr = 0;
    s->sysc = 0;
    s->wer = 0x3f;
    s->cfps = 0x69;
}

static uint64_t d2b_vendor_read(void *opaque, hwaddr offset, unsigned size)
{
    D2BUartVendor *s = opaque;

    /* Offset is relative to UART1 base+0x20, not UART1 base. */
    switch (offset + D2B_UART1_VENDOR) {
    case 0x20: return s->mdr1;         /* MDR1 */
    case 0x24: return s->mdr2;         /* MDR2 */
    case 0x40: return s->scr;          /* SCR  */
    case 0x44: return 0;               /* SSR  */
    case 0x48: return s->eblr;         /* EBLR */
    case 0x50: return 0x30;            /* MVR  */
    case 0x54: return s->sysc;         /* SYSC */
    case 0x58: return 1;               /* SYSS / reset complete */
    case 0x5c: return s->wer;          /* WER  */
    case 0x60: return s->cfps;         /* CFPS */
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "OMAP2420-D2B: unsupported UART1 vendor read 0x%"
                      HWADDR_PRIx "\n", offset + D2B_UART1_VENDOR);
        return 0;
    }
}

static void d2b_vendor_write(void *opaque, hwaddr offset,
                             uint64_t value, unsigned size)
{
    D2BUartVendor *s = opaque;
    uint8_t v = value & 0xff;

    switch (offset + D2B_UART1_VENDOR) {
    case 0x20: s->mdr1 = v & 0x7f; break;
    case 0x24: s->mdr2 = v; break;
    case 0x40: s->scr = v; break;
    case 0x48: s->eblr = v; break;
    case 0x54:
        s->sysc = v & 0x1d;
        if (v & 2) {
            d2b_vendor_reset(s);
        }
        break;
    case 0x5c: s->wer = v & 0x7f; break;
    case 0x60: s->cfps = v; break;
    case 0x44: /* read-only SSR */
    case 0x50: /* read-only MVR */
    case 0x58: /* read-only SYSS */
        qemu_log_mask(LOG_GUEST_ERROR,
                      "OMAP2420-D2B: write to read-only UART1 vendor register\n");
        break;
    default:
        qemu_log_mask(LOG_GUEST_ERROR,
                      "OMAP2420-D2B: unsupported UART1 vendor write 0x%"
                      HWADDR_PRIx "\n", offset + D2B_UART1_VENDOR);
        break;
    }
}

static const MemoryRegionOps d2b_uart_vendor_ops = {
    .read = d2b_vendor_read,
    .write = d2b_vendor_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid.min_access_size = 1,
    .valid.max_access_size = 1,
    .impl.min_access_size = 1,
    .impl.max_access_size = 1,
};

/* IRQ sink only: does NOT emulate the OMAP2 INTC or route to CPU IRQ. */
static void d2b_unrouted_uart_irq(void *opaque, int n, int level)
{
    D2BUartVendor *s = opaque;
    s->diagnostic_irq_transitions++;
    s->last_irq_level = level;
}

static void omap2420_d2b_init(MachineState *machine)
{
    D2BEarlyMachine *s = g_new0(D2BEarlyMachine, 1);
    MemoryRegion *sysmem = get_system_memory();
    Object *cpuobj;
    ARMCPU *cpu;
    qemu_irq irq;

    if (machine->ram_size < 16 * MiB ||
        machine->ram_size > D2B_SDRAM_MAX) {
        error_report("omap2420-uartdiag: RAM must be 16..128 MiB");
        exit(EXIT_FAILURE);
    }
    if (machine->smp.cpus != 1 ||
        strcmp(machine->cpu_type, ARM_CPU_TYPE_NAME("arm1136")) != 0) {
        error_report("omap2420-uartdiag: single arm1136 CPU only");
        exit(EXIT_FAILURE);
    }

    cpuobj = object_new(machine->cpu_type);
    if (object_property_find(cpuobj, "has_el3")) {
        object_property_set_bool(cpuobj, "has_el3", false, &error_fatal);
    }
    qdev_realize(DEVICE(cpuobj), NULL, &error_fatal);
    cpu = ARM_CPU(cpuobj);

    memory_region_init_ram(&s->sram, NULL, "omap2420.d2b.sram",
                           D2B_SRAM_SIZE, &error_fatal);
    memory_region_add_subregion(sysmem, D2B_SRAM_BASE, &s->sram);
    memory_region_add_subregion(sysmem, D2B_SDRAM_BASE, machine->ram);

    d2b_vendor_reset(&s->uart);

    /*
     * Real QEMU 16550A/serial-mm memory backend. An ARM guest store byte to
     * 0x4806a000 goes to THR and out via -serial stdio. Register spacing=4,
     * as in QEMU v9.1 omap_uart_init(..., regshift=2, ...).
     */
    irq = qemu_allocate_irq(d2b_unrouted_uart_irq, &s->uart, 0);
    serial_mm_init(sysmem, D2B_UART1_BASE, 2, irq,
                   48000000 / 16, serial_hd(0), DEVICE_LITTLE_ENDIAN);

    memory_region_init_io(&s->uart.mmio, NULL, &d2b_uart_vendor_ops,
                          &s->uart, "omap2420.d2b.uart1.vendor",
                          D2B_UART1_VENDOR_SZ);
    memory_region_add_subregion(sysmem, D2B_UART1_BASE + D2B_UART1_VENDOR,
                                &s->uart.mmio);

    s->boot.loader_start = D2B_SDRAM_BASE;
    s->boot.ram_size = machine->ram_size;
    if (!qtest_enabled()) {
        arm_load_kernel(cpu, machine, &s->boot);
    }
}

static void omap2420_d2b_class_init(MachineClass *mc)
{
    mc->desc = "OMAP2420 UART1 MMIO EARLY DIAG (NOT Nokia N95)";
    mc->init = omap2420_d2b_init;
    mc->default_cpu_type = ARM_CPU_TYPE_NAME("arm1136");
    mc->default_ram_size = D2B_SDRAM_MAX;
    mc->default_ram_id = "omap2420.d2b.sdram";
    mc->default_cpus = 1;
    mc->min_cpus = 1;
    mc->max_cpus = 1;
}

DEFINE_MACHINE("omap2420-uartdiag", omap2420_d2b_class_init)
