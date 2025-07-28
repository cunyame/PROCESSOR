# Pipelined MIPS32 Processor Simulation in Verilog

This project implements a simplified 5-stage pipelined MIPS32 processor in Verilog and simulates it using a custom testbench. The design supports a basic instruction set and demonstrates pipelined execution, including register updates and memory access for calculating factorial using loop-based control.

---

## 📁 Files

- `pipe_MIPS32.v` – Verilog module for pipelined MIPS32 processor.
- `test_mips32.v` – Testbench to simulate the processor and observe register/memory changes.
- `mips.vcd` – Waveform dump generated after simulation (viewable in GTKWave or Vivado).
- `README.md` – This file.

---

## ✅ Features

- Two-phase clocked pipeline: `clk1` and `clk2`
- 32 general-purpose registers
- 1024 32-bit memory locations
- Implements key instructions:
  - R-type: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `MUL`
  - I-type: `ADDI`, `SUBI`, `SLTI`, `LW`, `SW`, `BEQZ`, `BNEQZ`
  - Control: `HLT`
- Simulates factorial computation using loop

---

## 🔧 Instructions to Run

### 🛠 Requirements
- Xilinx Vivado (tested with 2024.2)
- Basic Verilog knowledge

### ▶️ Simulation Steps
1. Open Vivado → Create New Project → Add `pipe_MIPS32.v` and `test_mips32.v`
2. Set `test_mips32` as the top module.
3. Run behavioral simulation.
4. Observe simulation output or open `mips.vcd` in waveform viewer.
