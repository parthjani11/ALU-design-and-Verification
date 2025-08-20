# ALU Verification using SystemVerilog and QuestaSim

## Project Overview
This is an ongoing project focused on verifying an 8-bit Arithmetic Logic Unit (ALU) using SystemVerilog and QuestaSim. The aim is to create a layered and reusable testbench that checks the correctness of arithmetic and logical operations while following industry-level verification practices.

## Objectives
- Develop a self-checking SystemVerilog testbench for the ALU
- Use QuestaSim for simulation and debugging
- Generate random test inputs and compare predicted vs actual outputs through a scoreboard
- Verify corner cases such as overflow, underflow, and zero results

## Tools and Technologies
- Hardware Description Language: SystemVerilog
- Simulator: QuestaSim
- Verification Style: Layered Testbench (driver, monitor, scoreboard, coverage)

## Current Status
- ALU design module is ready
- Initial testbench is created and runs in QuestaSim
- Work is in progress for coverage and scoreboard implementation
- Next stage will include constrained randomization and assertions

## Next Steps
- Expand testbench into a UVM-like layered environment
- Add functional coverage for all ALU operations
- Automate regression runs and result logging
