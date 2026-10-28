// uvm/tb/tb_top.sv — UVM testbench top-level module
//
// Responsibilities:
//   1. Generate clock and instantiate the DUT + interface.
//   2. Mirror dut.u_regfile.regs into cpu_if.regs each cycle.
//      (The monitor reads cpu_if.regs to detect register writes.)
//   3. Propagate the driver's backdoor-write signals to dut.u_imem.mem.
//      (Direct hierarchical assignment; legal in VCS/Questa/Xcelium.)
//   4. Register the virtual interface in UVM config_db and call run_test().

`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import cpu_pkg::*;

    // ── Clock ────────────────────────────────────────────────────────
    logic clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ── Interface + DUT ──────────────────────────────────────────────
    cpu_if u_if (.clk(clk));

    cpu #(
        .IMEM_DEPTH (4096),
        .DMEM_DEPTH (4096),
        .HEX_FILE   ("")        // no file pre-load; driver backdoors the program
    ) dut (
        .clk      (clk),
        .rst_n    (u_if.rst_n),
        .dbg_pc   (u_if.dbg_pc),
        .dbg_instr(u_if.dbg_instr)
    );

    // ── Regfile mirror ───────────────────────────────────────────────
    // Copy the DUT register file into the interface every cycle.
    // The monitor uses cpu_if.regs (not the DUT hierarchy) so that the
    // clocking-block sampling gives it the correct setup-time view.
    always_ff @(posedge clk) begin
        for (int i = 0; i < 32; i++)
            u_if.regs[i] <= dut.u_regfile.regs[i];
    end

    // ── Imem backdoor ────────────────────────────────────────────────
    // The driver pulses imem_wr_en for one cycle per word.
    // $deposit writes directly to the simulation variable without creating
    // a second driver, so it doesn't conflict with imem's initial block.
    always @(posedge clk) begin
        if (u_if.imem_wr_en)
            $deposit(dut.u_imem.mem[u_if.imem_wr_addr], u_if.imem_wr_data);
    end

    // ── UVM startup ──────────────────────────────────────────────────
    initial begin
        // Make the virtual interface available to every UVM component
        uvm_config_db #(virtual cpu_if)::set(null, "uvm_test_top.*", "vif", u_if);

        // Run the test named on the command line:
        //   +UVM_TESTNAME=cpu_smoke_test
        //   +UVM_TESTNAME=cpu_hazard_test
        run_test();
    end

    // ── Optional: timeout guard ───────────────────────────────────────
    initial begin
        #500_000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500 µs — test hung?")
    end

endmodule
