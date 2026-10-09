/*
 * OMAP2420 EARLY-DIAGNOSTIC MACHINE, GATE D2a (RAM/CPU/ELF loader only).
 *
 * Copyright (c) 2026 UTM Nokia S60 compatibility research contributors.
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Not a Nokia N95 machine: no ROM, OMAP2 L4/INTC/UART/clock/timer/display.
 * SRAM / SDRAM base addresses are derived from QEMU v9.1.0 OMAP2 source.
 * Designed as a new QEMU v10.0.12-utm ARM system machine for tests only.
 */
#include "qemu/osdep.h"
#include "qapi/error.h"
#include "hw/arm/boot.h"
#include "hw/boards.h"
#include "hw/qdev-core.h"
#include "exec/address-spaces.h"
#include "qemu/error-report.h"
#include "qemu/units.h"
#include "system/qtest.h"
#include "target/arm/cpu.h"
#include "target/arm/cpu-qom.h"

#define D2A_SRAM_BASE    0x40200000ULL
#define D2A_SRAM_SIZE    0x000A0000ULL
#define D2A_SDRAM_BASE   0x80000000ULL
#define D2A_SDRAM_MAX    (128 * MiB)

typedef struct D2AEarlyMachine {
    MemoryRegion sram;
    struct arm_boot_info boot;
} D2AEarlyMachine;

static void omap2420_d2a_init(MachineState *machine)
{
    D2AEarlyMachine *s = g_new0(D2AEarlyMachine, 1);
    MemoryRegion *sysmem = get_system_memory();
    Object *cpuobj;
    ARMCPU *cpu;

    if (machine->ram_size < 16 * MiB ||
        machine->ram_size > D2A_SDRAM_MAX) {
        error_report("omap2420-earlydiag: RAM must be 16..128 MiB");
        exit(EXIT_FAILURE);
    }
    if (machine->smp.cpus != 1) {
        error_report("omap2420-earlydiag: single ARM1136 CPU only");
        exit(EXIT_FAILURE);
    }
    if (strcmp(machine->cpu_type, ARM_CPU_TYPE_NAME("arm1136")) != 0) {
        error_report("omap2420-earlydiag: use -cpu arm1136 only");
        exit(EXIT_FAILURE);
    }

    cpuobj = object_new(machine->cpu_type);
    if (object_property_find(cpuobj, "has_el3")) {
        object_property_set_bool(cpuobj, "has_el3", false, &error_fatal);
    }
    qdev_realize(DEVICE(cpuobj), NULL, &error_fatal);
    cpu = ARM_CPU(cpuobj);

    memory_region_init_ram(&s->sram, OBJECT(machine),
                           "omap2420.d2a.sram", D2A_SRAM_SIZE, &error_fatal);
    memory_region_add_subregion(sysmem, D2A_SRAM_BASE, &s->sram);
    memory_region_add_subregion(sysmem, D2A_SDRAM_BASE, machine->ram);

    s->boot.loader_start = D2A_SDRAM_BASE;
    s->boot.ram_size = machine->ram_size;
    if (!qtest_enabled()) {
        arm_load_kernel(cpu, machine, &s->boot);
    }

    /*
     * D2a has NO interrupt controller, MMIO devices, OMAP UART or L4 bus.
     * ARM semihosting is an explicit diagnostic side-channel, not guest UART.
     * MemoryRegion objects must remain valid for the machine's whole lifetime.
     */
}

static void omap2420_d2a_class_init(MachineClass *mc)
{
    mc->desc = "OMAP2420 EARLY DIAGNOSTIC CPU+SRAM+SDRAM (NO Nokia/N95)";
    mc->init = omap2420_d2a_init;
    mc->default_cpu_type = ARM_CPU_TYPE_NAME("arm1136");
    mc->default_ram_size = D2A_SDRAM_MAX;
    mc->default_ram_id = "omap2420.d2a.sdram";
    mc->default_cpus = 1;
    mc->min_cpus = 1;
    mc->max_cpus = 1;
}

DEFINE_MACHINE("omap2420-earlydiag", omap2420_d2a_class_init)
