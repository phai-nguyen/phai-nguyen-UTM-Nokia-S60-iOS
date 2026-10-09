/*
 * Gate D2c: OMAP2420 UART1 RX loopback and interrupt-controller diagnostic.
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * THIS IS NOT A NOKIA N95 / FULL OMAP2420 MACHINE. INTC subset only.
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
#define D2C_INTC_BASE 0x480FE000ULL
#define D2C_INTC_SIZE 0x1000
#define D2C_UART1_IRQ 72
#define D2C_VECTOR_SIZE 0x1000

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
    MemoryRegion vector_ram;
    struct D2CIntc *intc;
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


/*
 * Early OMAP24xx INTC subset. Three 32-source banks model 96 SoC inputs.
 * Register offset/banking matches QEMU 9.1 hw/intc/omap_intc.c.
 * This implements UART1 IRQ #72 and IRQ-output propagation to ARM1136.
 * Missing: priority scheduler, FIQ, ILR, full software interrupt semantics.
 * Deliberately isolated from firmware-facing Nokia/N95 compatibility.
 */
typedef struct D2CIntc {
    MemoryRegion mmio;
    qemu_irq cpu_irq;
    uint32_t inputs[3];
    uint32_t mir[3];
    uint32_t sir;
    bool acked;
    bool irq_level;
} D2CIntc;

static void d2c_intc_update(D2CIntc *s)
{
    bool level = false;
    uint32_t selected = 0x7f;

    /* Choose the lowest active unmasked IRQ as the diagnostic SIR_IRQ. */
    for (int bank = 0; bank < 3; bank++) {
        uint32_t pending = s->inputs[bank] & ~s->mir[bank];
        if (pending) {
            selected = bank * 32 + __builtin_ctz(pending);
            level = true;
            break;
        }
    }
    s->sir = selected;
    if (s->irq_level != level) {
        s->irq_level = level;
        qemu_set_irq(s->cpu_irq, level);
    }
}

static void d2c_uart_irq_input(void *opaque, int line, int level)
{
    D2CIntc *s = opaque;
    if (line != D2C_UART1_IRQ) {
        return;
    }
    const int bank = line / 32;
    const uint32_t bit = UINT32_C(1) << (line % 32);
    if (level) {
        s->inputs[bank] |= bit;
    } else {
        s->inputs[bank] &= ~bit;
    }
    d2c_intc_update(s);
}

static uint64_t d2c_intc_read(void *opaque, hwaddr offset, unsigned size)
{
    D2CIntc *s = opaque;
    if (offset == 0x00) { return 0x21; } /* INTC_REVISION */
    if (offset == 0x14) { return 1; }    /* INTC_SYSSTATUS */
    if (offset == 0x40) { return s->sir; }
    if (offset == 0x48) { return 4; }
    if (offset >= 0x80 && offset < 0xe0) {
        int bank = (offset - 0x80) / 0x20;
        hwaddr reg = (offset - 0x80) % 0x20;
        if (bank < 3) {
            switch (reg) {
            case 0x00: return s->inputs[bank];  /* ITR */
            case 0x04: return s->mir[bank];     /* MIR */
            case 0x08: case 0x0c: return 0;     /* MIR CLR/SET */
            case 0x18: return s->inputs[bank] & ~s->mir[bank]; /* PENDING IRQ */
            case 0x1c: return 0;                /* PENDING FIQ */
            default: return 0;
            }
        }
    }
    return 0;
}

static void d2c_intc_write(void *opaque, hwaddr offset,
                            uint64_t value, unsigned size)
{
    D2CIntc *s = opaque;
    if (offset == 0x10) {               /* INTC_SYSCONFIG */
        if (value & 2) {
            for (int bank = 0; bank < 3; bank++) {
                s->mir[bank] = UINT32_MAX;
            }
            d2c_intc_update(s);
        }
        return;
    }
    if (offset == 0x48) {               /* INTC_CONTROL NEWIRQAGR */
        if (value & 1) {
            s->acked = true;
            d2c_intc_update(s);
        }
        return;
    }
    if (offset >= 0x80 && offset < 0xe0) {
        int bank = (offset - 0x80) / 0x20;
        hwaddr reg = (offset - 0x80) % 0x20;
        if (bank >= 3) { return; }
        switch (reg) {
        case 0x04: s->mir[bank] = value; break;
        case 0x08: s->mir[bank] &= ~(uint32_t)value; break;
        case 0x0c: s->mir[bank] |= (uint32_t)value; break;
        default: return;
        }
        d2c_intc_update(s);
    }
}

static const MemoryRegionOps d2c_intc_ops = {
    .read = d2c_intc_read,
    .write = d2c_intc_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid.min_access_size = 4,
    .valid.max_access_size = 4,
    .impl.min_access_size = 4,
    .impl.max_access_size = 4,
};

static void omap2420_d2c_init(MachineState *machine)
{
    D2BEarlyMachine *s = g_new0(D2BEarlyMachine, 1);
    MemoryRegion *sysmem = get_system_memory();
    Object *cpuobj;
    ARMCPU *cpu;
    qemu_irq irq;

    if (machine->ram_size < 16 * MiB ||
        machine->ram_size > D2B_SDRAM_MAX) {
        error_report("omap2420-intcdiag: RAM must be 16..128 MiB");
        exit(EXIT_FAILURE);
    }
    if (machine->smp.cpus != 1 ||
        strcmp(machine->cpu_type, ARM_CPU_TYPE_NAME("arm1136")) != 0) {
        error_report("omap2420-intcdiag: single arm1136 CPU only");
        exit(EXIT_FAILURE);
    }

    cpuobj = object_new(machine->cpu_type);
    if (object_property_find(cpuobj, "has_el3")) {
        object_property_set_bool(cpuobj, "has_el3", false, &error_fatal);
    }
    qdev_realize(DEVICE(cpuobj), NULL, &error_fatal);
    cpu = ARM_CPU(cpuobj);

    memory_region_init_ram(&s->sram, NULL, "omap2420.d2c.sram",
                           D2B_SRAM_SIZE, &error_fatal);
    memory_region_add_subregion(sysmem, D2B_SRAM_BASE, &s->sram);
    memory_region_add_subregion(sysmem, D2B_SDRAM_BASE, machine->ram);

    d2b_vendor_reset(&s->uart);
    s->intc = g_new0(D2CIntc, 1);
    s->intc->cpu_irq = qdev_get_gpio_in(DEVICE(cpu), ARM_CPU_IRQ);
    for (int i = 0; i < 3; i++) { s->intc->mir[i] = UINT32_MAX; }
    memory_region_init_io(&s->intc->mmio, NULL, &d2c_intc_ops,
                          s->intc, "omap2420.d2c.intc", D2C_INTC_SIZE);
    memory_region_add_subregion(sysmem, D2C_INTC_BASE, &s->intc->mmio);
    memory_region_init_ram(&s->vector_ram, NULL, "omap2420.d2c.vectors",
                           D2C_VECTOR_SIZE, &error_fatal);
    memory_region_add_subregion(sysmem, 0, &s->vector_ram);

    /*
     * Real QEMU 16550A/serial-mm memory backend. An ARM guest store byte to
     * 0x4806a000 goes to THR and out via -serial stdio. Register spacing=4,
     * as in QEMU v9.1 omap_uart_init(..., regshift=2, ...).
     */
    irq = qemu_allocate_irq(d2c_uart_irq_input, s->intc, D2C_UART1_IRQ);
    serial_mm_init(sysmem, D2B_UART1_BASE, 2, irq,
                   48000000 / 16, serial_hd(0), DEVICE_LITTLE_ENDIAN);

    memory_region_init_io(&s->uart.mmio, NULL, &d2b_uart_vendor_ops,
                          &s->uart, "omap2420.d2c.uart1.vendor",
                          D2B_UART1_VENDOR_SZ);
    memory_region_add_subregion(sysmem, D2B_UART1_BASE + D2B_UART1_VENDOR,
                                &s->uart.mmio);

    s->boot.loader_start = D2B_SDRAM_BASE;
    s->boot.ram_size = machine->ram_size;
    if (!qtest_enabled()) {
        arm_load_kernel(cpu, machine, &s->boot);
    }
}

static void omap2420_d2c_class_init(MachineClass *mc)
{
    mc->desc = "OMAP2420 UART1 RX+INTC EARLY DIAG (NOT Nokia N95)";
    mc->init = omap2420_d2c_init;
    mc->default_cpu_type = ARM_CPU_TYPE_NAME("arm1136");
    mc->default_ram_size = D2B_SDRAM_MAX;
    mc->default_ram_id = "omap2420.d2c.sdram";
    mc->default_cpus = 1;
    mc->min_cpus = 1;
    mc->max_cpus = 1;
}

DEFINE_MACHINE("omap2420-intcdiag", omap2420_d2c_class_init)
