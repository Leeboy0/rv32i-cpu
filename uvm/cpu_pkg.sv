// uvm/cpu_pkg.sv — RV32I CPU UVM environment
//
// Each class lives in its own file; this package only pulls them in.
// Include order matters: a class must be included after anything it
// references.  The Makefile adds every subdirectory to +incdir.
//
// Directory layout:
//   agent/      cpu_prog_item, cpu_reg_trans, cpu_driver, cpu_monitor, cpu_agent
//   ref_model/  rv32i_ref_model (embedded ISA interpreter, not a UVM class)
//   env/        cpu_scoreboard, cpu_coverage, cpu_env
//   seq/        cpu_smoke_seq, cpu_load_use_seq, cpu_fwd_seq
//   tests/      cpu_base_test, cpu_smoke_test, cpu_hazard_test
//   tb/         cpu_if, tb_top (compiled outside the package)

package cpu_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Two analysis-imp tags for the scoreboard's dual inputs
    `uvm_analysis_imp_decl(_prog)   // cpu_prog_item (from driver)
    `uvm_analysis_imp_decl(_trans)  // cpu_reg_trans  (from monitor)

    // Transactions
    `include "cpu_prog_item.sv"
    `include "cpu_reg_trans.sv"

    // Reference model
    `include "rv32i_ref_model.sv"

    // Agent
    `include "cpu_driver.sv"
    `include "cpu_monitor.sv"
    `include "cpu_agent.sv"

    // Environment
    `include "cpu_scoreboard.sv"
    `include "cpu_coverage.sv"
    `include "cpu_env.sv"

    // Sequences
    `include "cpu_smoke_seq.sv"
    `include "cpu_load_use_seq.sv"
    `include "cpu_fwd_seq.sv"

    // Tests
    `include "cpu_base_test.sv"
    `include "cpu_smoke_test.sv"
    `include "cpu_hazard_test.sv"

endpackage : cpu_pkg
