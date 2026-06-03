`timescale 1ns/1ps

module tb_cpu;
    logic        clk = 0;
    logic        rst_n;
    logic [31:0] dbg_pc;
    logic [31:0] dbg_instr;

    always #5 clk = ~clk;  // 100 MHz

    cpu dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .dbg_pc    (dbg_pc),
        .dbg_instr (dbg_instr)
    );

    initial begin
        $dumpfile("sim/tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;

        repeat (50) @(posedge clk);

        if (dut.u_regfile.regs[3] === 32'd8)
            $display("[PASS] x3 = %0d", dut.u_regfile.regs[3]);
        else
            $display("[FAIL] x3 = %0d (expected 8)", dut.u_regfile.regs[3]);

        $finish;
    end

    // Per-cycle trace using the clean debug ports
    always @(posedge clk) if (rst_n)
        $display("t=%0t  PC=%h  INSTR=%h", $time, dbg_pc, dbg_instr);
endmodule