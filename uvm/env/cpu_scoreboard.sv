// uvm/env/cpu_scoreboard.sv — compares observed write sequences to ISA model
//
//  Strategy: run the reference model on-demand.  When the monitor
//  reports a write (rd, rd_val), advance the ref model until it
//  also produces a write, then compare.  In-order execution
//  guarantees the sequences are aligned even across stalls/flushes
//  (pipeline NOPs produce no writes in either model).

`ifndef CPU_SCOREBOARD_SV
`define CPU_SCOREBOARD_SV

class cpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_scoreboard)

    uvm_analysis_imp_prog  #(cpu_prog_item,  cpu_scoreboard) prog_export;
    uvm_analysis_imp_trans #(cpu_reg_trans,  cpu_scoreboard) trans_export;

    rv32i_ref_model isa_model;
    int unsigned    checks_passed = 0;
    int unsigned    checks_failed = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        prog_export  = new("prog_export",  this);
        trans_export = new("trans_export", this);
        isa_model    = new();
    endfunction

    // Called by driver's prog_ap: reset and reload the ISA model
    function void write_prog(cpu_prog_item item);
        isa_model.reset();
        isa_model.load_imem(item.imem, item.prog_len);
        `uvm_info("SCB", $sformatf("Loaded program (%0d words)", item.prog_len), UVM_MEDIUM)
    endfunction

    // Called for every write event the monitor observes
    function void write_trans(cpu_reg_trans t);
        logic [4:0]  exp_rd;
        logic [31:0] exp_val;

        isa_model.next_write(exp_rd, exp_val);   // advance model to next write

        if (t.rd !== exp_rd || t.rd_val !== exp_val) begin
            `uvm_error("SCB",
                $sformatf("MISMATCH: DUT x%0d=%08h | REF x%0d=%08h  (cyc %0d)",
                          t.rd, t.rd_val, exp_rd, exp_val, t.cycle))
            checks_failed++;
        end else begin
            `uvm_info("SCB",
                $sformatf("OK x%0d=%08h  (cyc %0d)", t.rd, t.rd_val, t.cycle),
                UVM_HIGH)
            checks_passed++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB",
            $sformatf("Scoreboard: %0d PASSED  %0d FAILED",
                      checks_passed, checks_failed),
            UVM_NONE)
        if (checks_failed > 0)
            `uvm_fatal("SCB", "*** TEST FAILED ***")
    endfunction

endclass : cpu_scoreboard

`endif // CPU_SCOREBOARD_SV
