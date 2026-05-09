# RV32I Single-Cycle Processor
 
A RISC-V **RV32I** single-cycle CPU written in SystemVerilog, developed with a verification-first methodology. Each module is paired with a self-checking testbench (In progress). 

## Roadmap
 
### v1.0 — Single-cycle complete

-[x] Basic Single Cycle Architecture 
-[x] Testbench Development 
-[ ] Test and profiling 

### v2.0 — Classic 5-stage pipeline
 
- [ ] Stage split: IF / ID / EX / MEM / WB with pipeline registers
- [ ] Hazard detection unit
- [ ] Forwarding / bypass network
- [ ] Re-run `riscv-tests` end-to-end

**Author:** [@Leeboy0](https://github.com/Leeboy0)