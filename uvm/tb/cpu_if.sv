// uvm/tb/cpu_if.sv — SystemVerilog interface wrapping all DUT I/O
`timescale 1ns/1ps
//
// Responsibilities:
//   1. Clocking blocks for skew-free driver and monitor access.
//   2. Mirror of the register file (populated each cycle in tb_top
//      via hierarchical reference — dut.u_regfile.regs).
//   3. Backdoor write port to instruction memory (driven by the driver;
//      tb_top connects it to dut.u_imem.mem).

interface cpu_if (input logic clk);

    // ── DUT ports ────────────────────────────────────────────────────
    logic        rst_n;
    logic [31:0] dbg_pc;
    logic [31:0] dbg_instr;

    // ── Regfile mirror (tb_top writes this every cycle) ──────────────
    logic [31:0] regs [0:31];

    // ── Instruction-memory backdoor (driver writes; tb_top applies) ──
    logic [31:0] imem_wr_data;
    logic [11:0] imem_wr_addr;
    logic        imem_wr_en;    // pulse high for one cycle per word

    // ── Driver clocking block ─────────────────────────────────────────
    clocking drv_cb @(posedge clk);
        default output #1;
        output rst_n;
        output imem_wr_data;
        output imem_wr_addr;
        output imem_wr_en;
    endclocking

    // ── Monitor clocking block ────────────────────────────────────────
    clocking mon_cb @(posedge clk);
        default input #1;
        input rst_n;
        input dbg_pc;
        input dbg_instr;
        input regs;
    endclocking

    modport drv_mp (clocking drv_cb, input clk);
    modport mon_mp (clocking mon_cb, input clk);

endinterface
