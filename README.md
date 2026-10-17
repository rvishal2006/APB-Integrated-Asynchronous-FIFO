

# APB-Integrated Asynchronous FIFO

## Overview

This project implements an APB-integrated asynchronous FIFO using SystemVerilog. It enables data buffering between independently clocked domains using a FIFO memory, Gray-code pointers, clock-domain crossing synchronizers, and an APB slave interface.

The design is verified using a self-checking testbench in Xilinx Vivado Simulator.

## Features

- 32-bit FIFO data width
- FIFO depth of 16 words
- Asynchronous write and read clock domains
- Gray-code read and write pointers
- Clock-domain crossing synchronizers
- APB slave interface
- FIFO FULL and EMPTY status
- APB read/write support with wait-state handling
- Error handling for invalid FIFO accesses
- Self-checking SystemVerilog testbench

## Architecture

The design consists of three major components:

1. **Asynchronous FIFO:** Stores data and manages read/write pointers across independent clock domains.
2. **APB Interface:** Provides processor-side access to FIFO data and status registers.
3. **Testbench:** Verifies data ordering, FIFO status, and empty-read error handling.

## Configuration

| Parameter | Value |
|---|---|
| Data width | 32 bits |
| FIFO depth | 16 words |
| APB data register | 0x00 |
| APB status register | 0x04 |
| APB clock | PCLK |
| Read clock | rd_clk |
| Simulation tool | Xilinx Vivado Simulator |
| HDL | SystemVerilog |

## Register Map

| Address | Register | Description |
|---|---|---|
| 0x00 | DATA | Write data into or read data from the FIFO |
| 0x04 | STATUS | Reports FIFO status |

The exact status-bit definitions should match the RTL implementation.

## Project Files

- `rtl/async_fifo.sv` — Asynchronous FIFO implementation.
- `rtl/apb_async_fifo.sv` — APB slave and FIFO integration.
- `testbench/tb_apb_async_fifo.sv` — Self-checking simulation testbench.

## Verification

The testbench checks FIFO data ordering using the test values:

- `12345678`
- `AABBCCDD`
- `DEADBEEF`

It also checks FIFO status and empty-read error handling.

**Expected result:** `ALL TESTS PASSED` when all testbench checks succeed.

## Tools Required

- Xilinx Vivado
- SystemVerilog simulation support

## How to Run

1. Open Vivado and create a new RTL project.
2. Add `async_fifo.sv` and `apb_async_fifo.sv` as design sources.
3. Add `tb_apb_async_fifo.sv` as a simulation source.
4. Set `tb_apb_async_fifo` as the simulation top module.
5. Run Behavioral Simulation.
6. Check the simulation log for the testbench pass message.

## Applications

- On-chip communication between clock domains
- SoC peripheral buffering
- Processor-to-hardware data transfer
- Digital system design and verification

