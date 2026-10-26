# 8-Bit 5-Stage Pipelined RISC Processor (`risc8_5stage`)

A custom 8-bit Harvard-architecture RISC processor featuring a 5-stage pipeline (`IF`, `ID`, `EX`, `MEM`, `WB`), designed in Verilog HDL and verified using Xilinx Vivado. The core implements full data forwarding, load-use hazard stalling, branch/jump flushing, and a self-checking regression testbench.

## Key Architectural Features

* **Harvard Memory Architecture:**
  * **Instruction Memory (`imem`):** 256 x 16-bit ROM initialized with a comprehensive self-test assembly program.
  * **Data Memory (`dmem`):** 256 x 8-bit RAM with asynchronous read and synchronous write.
* **Register File (`regfile`):**
  * Eight 8-bit general-purpose registers (`R0`–`R7`, where `R0` is a normal writable register).
  * Asynchronous dual-read ports and a synchronous write port.
  * Built-in **WB-to-ID bypass** allowing simultaneous read and write to the same register within a single clock cycle.
* **5-Stage Pipeline (`risc8_5stage_core`):**
  * **IF (Instruction Fetch):** Program Counter (`PC`) management, instruction fetch, and priority handling for branches, halts, and stalls.
  * **ID (Instruction Decode):** Opcode decoding, register file reading, operand selection, and hazard detection.
  * **EX (Execute):** 8-bit ALU operations, architectural flag updates (`Z`, `C`), forwarding muxes, and branch resolution.
  * **MEM (Memory Access):** Data memory read/write operations.
  * **WB (Write Back):** Result selection (ALU vs. Memory) and instruction retirement tracking (`instr_done` and `halted`).
* **Hazard Detection & Forwarding (`hazard_unit`):**
  * **EX/MEM & MEM/WB Forwarding:** Resolves Read-After-Write (RAW) data hazards by forwarding results directly to EX stage operands.
  * **Load-Use Stall:** Detects load-use dependencies (`LD` followed immediately by an instruction consuming the loaded register) and inserts a 1-cycle pipeline bubble.
  * **Control Hazard Flush:** Automatically squashes wrong-path instructions in `IF/ID` and `ID/EX` upon taken branches (`JMP`, `BZ`, `BNZ`) or `HLT`.
* **Timing Constraints:**
  * Targeted for a 5.000 ns system clock period (**200 MHz** `sys_clk` defined in `timing.xdc`).

## Instruction Set Architecture (16-Bit ISA)

Instructions are 16 bits wide (`[15:12]` Opcode, `[11:9]` `rd`, `[8:6]` `rs1`, `[5:3]` `rs2`, or `[7:0]` `imm8`):

| Opcode | Mnemonic | Format | Description | Flags Updated |
| :---: | :--- | :--- | :--- | :---: |
| `4'h0` | `NOP` | `0000_xxxx_xxxx_xxxx` | No Operation | None |
| `4'h1` | `ADD rd, rs1, rs2` | `0001_ddd_aaa_bbb_xxx` | `rd = rs1 + rs2` | `Z`, `C` |
| `4'h2` | `SUB rd, rs1, rs2` | `0010_ddd_aaa_bbb_xxx` | `rd = rs1 - rs2` (`C=1` indicates borrow) | `Z`, `C` |
| `4'h3` | `AND rd, rs1, rs2` | `0011_ddd_aaa_bbb_xxx` | `rd = rs1 & rs2` | `Z`, `C=0` |
| `4'h4` | `OR  rd, rs1, rs2` | `0100_ddd_aaa_bbb_xxx` | `rd = rs1 \| rs2` | `Z`, `C=0` |
| `4'h5` | `XOR rd, rs1, rs2` | `0101_ddd_aaa_bbb_xxx` | `rd = rs1 ^ rs2` | `Z`, `C=0` |
| `4'h6` | `SHL rd, rs1` | `0110_ddd_aaa_xxxxxx` | `rd = rs1 << 1`, `C = rs1[7]` | `Z`, `C` |
| `4'h7` | `SHR rd, rs1` | `0111_ddd_aaa_xxxxxx` | `rd = rs1 >> 1`, `C = rs1[0]` | `Z`, `C` |
| `4'h8` | `LDI rd, imm8` | `1000_ddd_x_iiiiiiii` | `rd = imm8` | None |
| `4'h9` | `ADDI rd, imm8` | `1001_ddd_x_iiiiiiii` | `rd = rd + imm8` | `Z`, `C` |
| `4'hA` | `LD  rd, [rs1]` | `1010_ddd_aaa_xxxxxx` | `rd = dmem[rs1]` | None |
| `4'hB` | `ST  rd, [rs1]` | `1011_ddd_aaa_xxxxxx` | `dmem[rs1] = rd` | None |
| `4'hC` | `JMP addr8` | `1100_xxxx_aaaaaaaa` | `PC = addr8` | None |
| `4'hD` | `BZ  addr8` | `1101_xxxx_aaaaaaaa` | `if (Z == 1) PC = addr8` | None |
| `4'hE` | `BNZ addr8` | `1110_xxxx_aaaaaaaa` | `if (Z == 0) PC = addr8` | None |
| `4'hF` | `HLT` | `1111_xxxx_xxxx_xxxx` | Halt processor after retiring older instructions | None |

## Repository Structure

* `risc8_5stage.srcs/sources_1/new/`
  * `risc8_5stage_core.v` — Top-level 5-stage pipelined CPU core.
  * `control_unit.v` — Instruction decoder generating datapath and hazard control signals.
  * `alu.v` — 8-bit combinational Arithmetic Logic Unit.
  * `hazard_unit.v` — Data forwarding selector and load-use stall generator.
  * `regfile.v` — 8 x 8-bit register file with WB-to-ID internal bypass.
  * `imem.v` — 256 x 16-bit instruction ROM containing the verification program.
  * `dmem.v` — 256 x 8-bit data RAM.
* `risc8_5stage.srcs/sim_1/new/`
  * `tb_risc8_5stage.v` — Self-checking testbench (100 MHz simulation clock).
* `risc8_5stage.srcs/constrs_1/new/`
  * `timing.xdc` — Xilinx Design Constraints (`sys_clk` @ 200 MHz).
* `risc8_5stage.xpr` — Xilinx Vivado project file.
* `tb_risc8_5stage_behav.wcfg` — Vivado waveform configuration file.

## Verification & Simulation

The testbench (`tb_risc8_5stage.v`) runs an automated self-checking regression suite that verifies:
1. ALU arithmetic, bitwise operations, shifts, carry/borrow generation, and zero flag semantics.
2. EX/MEM and MEM/WB data forwarding paths (`forwarded_a`, `forwarded_b`) and WB-to-ID register file bypasses.
3. Load-use hazard detection (1 stall cycle inserted).
4. Control hazard flushing across 6 taken branches/jumps and post-`HLT` instructions (verifying that squashed instructions never retire).
5. Final architectural state after 34 retired instructions in 51 clock cycles (`*** ALL TESTS PASSED: 24 checks ***`).

### Running the Simulation in Vivado
1. Open `risc8_5stage.xpr` in **Xilinx Vivado**.
2. In the **Flow Navigator**, click **Run Simulation** -> **Run Behavioral Simulation**.
3. Check the Tcl Console for the `*** ALL TESTS PASSED: 24 checks ***` confirmation message.
