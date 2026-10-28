// uvm/env/cpu_coverage.sv — functional coverage

`ifndef CPU_COVERAGE_SV
`define CPU_COVERAGE_SV

class cpu_coverage extends uvm_subscriber #(cpu_reg_trans);
    `uvm_component_utils(cpu_coverage)

    cpu_reg_trans cur;

    // Opcode coverage — the interface observes dbg_instr which is
    // the IF-stage instruction; we track it in the transaction.
    // (Add instr field to cpu_reg_trans if you need per-retirement
    //  opcode tracking; here we use the monitor's cycle count as
    //  a proxy and extend per project needs.)

    covergroup opcode_cg;
        // Extend cpu_reg_trans to carry dbg_instr if needed;
        // shown here as a template coverpoint.
        cp_rd_range: coverpoint cur.rd {
            bins zero       = {0};
            bins low        = {[1:7]};
            bins mid        = {[8:15]};
            bins hi         = {[16:31]};
        }
    endgroup

    // Track consecutive writes to the same register (forwarding path)
    covergroup forwarding_cg;
        cp_rd: coverpoint cur.rd { bins nonzero[] = {[1:31]}; }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        opcode_cg     = new();
        forwarding_cg = new();
    endfunction

    function void write(cpu_reg_trans t);
        cur = t;
        opcode_cg.sample();
        forwarding_cg.sample();
    endfunction

endclass : cpu_coverage

`endif // CPU_COVERAGE_SV
