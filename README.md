# RV32I in order pipelined Processor
 
A RISC-V **RV32I** single-cycle CPU written in SystemVerilog, developed with a verification-first methodology. Each module is paired with a self-checking testbench (In progress). 

## Roadmap
 
### v1.0 — Single-cycle complete

- [x] Basic Single Cycle Architecture 
- [x] Testbench Development 
- [ ] Test and profiling 

### v2.0 — Classic 5-stage pipeline
 
- [x] Stage split: IF / ID / EX / MEM / WB with pipeline registers
- [x] Hazard detection unit
- [x] Forwarding / bypass network
- [ ] Re-run `riscv-tests` end-to-end

**Author:** [@Leeboy0](https://github.com/Leeboy0)