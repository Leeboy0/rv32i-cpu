// rv32i_cpu/tb/tb_alu.sv
// Two-part ALU testbench:
//   Part 1 — directed corner cases (explicit vectors)
//   Part 2 — constrained random with self-checking scoreboard

`timescale 1ns/1ps

module tb_alu;

    // DUT signals
    logic [31:0] a, b;
    logic [3:0]  alu_op;
    logic [31:0] result;
    logic        zero;

    // ALU op encodings (must match alu.sv)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SLTU = 4'b0110;
    localparam ALU_SLL  = 4'b0111;
    localparam ALU_SRL  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;

    // Scoreboard counters
    integer passed, failed, total;

    // Instantiate DUT
    alu dut (
        .a       (a),
        .b       (b),
        .alu_op  (alu_op),
        .result  (result),
        .zero    (zero)
    );

    // ----------------------------------------------------------------
    // Reference model — pure combinational, mirrors alu.sv exactly
    // ----------------------------------------------------------------
    function automatic [31:0] ref_alu;
        input [31:0] ra, rb;
        input [3:0]  op;
        case (op)
            ALU_ADD  : ref_alu = ra + rb;
            ALU_SUB  : ref_alu = ra - rb;
            ALU_AND  : ref_alu = ra & rb;
            ALU_OR   : ref_alu = ra | rb;
            ALU_XOR  : ref_alu = ra ^ rb;
            ALU_SLT  : ref_alu = ($signed(ra) < $signed(rb)) ? 32'd1 : 32'd0;
            ALU_SLTU : ref_alu = (ra < rb)                   ? 32'd1 : 32'd0;
            ALU_SLL  : ref_alu = ra << rb[4:0];
            ALU_SRL  : ref_alu = ra >> rb[4:0];
            ALU_SRA  : ref_alu = $signed(ra) >>> rb[4:0];
            default  : ref_alu = 32'b0;
        endcase
    endfunction

    // ----------------------------------------------------------------
    // Task: apply vector, check result, print pass/fail
    // ----------------------------------------------------------------
    task automatic check;
        input [31:0]  ta, tb_in;
        input [3:0]   top;
        input [31:0]  expected;
        input [63:0]  test_num;
        input [127:0] label;
        logic [31:0] exp_result;
        begin
            a      = ta;
            b      = tb_in;
            alu_op = top;
            #5;  // let combinational logic settle

            exp_result = expected;
            total = total + 1;

            if (result !== exp_result) begin
                $display("FAIL [%0d] %s: a=%h b=%h op=%b | got=%h expected=%h",
                         test_num, label, ta, tb_in, top, result, exp_result);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end

            // Check zero flag independently
            if (zero !== (result == 32'b0)) begin
                $display("FAIL [%0d] zero flag mismatch: result=%h zero=%b",
                         test_num, result, zero);
                failed = failed + 1;
                total  = total  + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // PART 1 — Directed corner cases
    // ----------------------------------------------------------------
    task run_directed;
        integer i;
        begin
            $display("\n=== Part 1: Directed corner cases ===");

            // ADD
            check(32'h00000001, 32'h00000001, ALU_ADD, 32'h00000002, 1,  "ADD basic       ");
            check(32'hFFFFFFFF, 32'h00000001, ALU_ADD, 32'h00000000, 2,  "ADD overflow    ");
            check(32'h7FFFFFFF, 32'h00000001, ALU_ADD, 32'h80000000, 3,  "ADD signed ovfl ");
            check(32'h00000000, 32'h00000000, ALU_ADD, 32'h00000000, 4,  "ADD zero+zero   ");

            // SUB
            check(32'h00000005, 32'h00000003, ALU_SUB, 32'h00000002, 5,  "SUB basic       ");
            check(32'h00000000, 32'h00000001, ALU_SUB, 32'hFFFFFFFF, 6,  "SUB underflow   ");
            check(32'h80000000, 32'h00000001, ALU_SUB, 32'h7FFFFFFF, 7,  "SUB signed ovfl ");

            // AND / OR / XOR
            check(32'hFF00FF00, 32'h0F0F0F0F, ALU_AND, 32'h0F000F00, 8,  "AND             ");
            check(32'hFF00FF00, 32'h0F0F0F0F, ALU_OR,  32'hFF0FFF0F, 9,  "OR              ");
            check(32'hFF00FF00, 32'h0F0F0F0F, ALU_XOR, 32'hF00FF00F, 10, "XOR             ");
            check(32'hFFFFFFFF, 32'hFFFFFFFF, ALU_XOR, 32'h00000000, 11, "XOR same inputs ");

            // SLT (signed)
            check(32'hFFFFFFFF, 32'h00000001, ALU_SLT,  32'h00000001, 12, "SLT neg<pos     ");
            check(32'h00000001, 32'hFFFFFFFF, ALU_SLT,  32'h00000000, 13, "SLT pos>neg     ");
            check(32'h00000005, 32'h00000005, ALU_SLT,  32'h00000000, 14, "SLT equal       ");

            // SLTU (unsigned)
            check(32'hFFFFFFFF, 32'h00000001, ALU_SLTU, 32'h00000000, 15, "SLTU large>small");
            check(32'h00000001, 32'hFFFFFFFF, ALU_SLTU, 32'h00000001, 16, "SLTU small<large");

            // Shifts — boundary values
            check(32'h00000001, 32'h00000001, ALU_SLL, 32'h00000002, 17, "SLL by 1        ");
            check(32'h00000001, 32'h0000001F, ALU_SLL, 32'h80000000, 18, "SLL by 31       ");
            check(32'h00000001, 32'h00000020, ALU_SLL, 32'h00000001, 19, "SLL by 32 (nop) "); // b[4:0]=0
            check(32'h80000000, 32'h00000001, ALU_SRL, 32'h40000000, 20, "SRL by 1        ");
            check(32'h80000000, 32'h0000001F, ALU_SRL, 32'h00000001, 21, "SRL by 31       ");
            check(32'h80000000, 32'h00000001, ALU_SRA, 32'hC0000000, 22, "SRA sign extend ");
            check(32'h80000000, 32'h0000001F, ALU_SRA, 32'hFFFFFFFF, 23, "SRA by 31       ");
            check(32'h7FFFFFFF, 32'h0000001F, ALU_SRA, 32'h00000000, 24, "SRA pos by 31   ");

            // Zero flag
            check(32'h00000005, 32'h00000005, ALU_SUB, 32'h00000000, 25, "zero flag set   ");
            check(32'h00000005, 32'h00000004, ALU_SUB, 32'h00000001, 26, "zero flag clear ");
        end
    endtask

    // ----------------------------------------------------------------
    // PART 2 — Constrained random with scoreboard
    // ----------------------------------------------------------------
    task run_random;
        integer i;
        logic [31:0] ra, rb, exp;
        logic [3:0]  op;
        begin
            $display("\n=== Part 2: Constrained random (500 transactions) ===");

            for (i = 0; i < 500; i = i + 1) begin
                // Random operands — bias toward boundary values 1-in-8 chance
                if ($urandom_range(0,7) == 0)
                    ra = {$urandom_range(0,3) == 0 ? 32'h00000000 :
                          $urandom_range(0,1) == 0 ? 32'hFFFFFFFF :
                          $urandom_range(0,1) == 0 ? 32'h7FFFFFFF : 32'h80000000};
                else
                    ra = {$urandom(), $urandom()} >> 32;  // 32-bit random

                if ($urandom_range(0,7) == 0)
                    rb = {$urandom_range(0,3) == 0 ? 32'h00000000 :
                          $urandom_range(0,1) == 0 ? 32'hFFFFFFFF :
                          $urandom_range(0,1) == 0 ? 32'h7FFFFFFF : 32'h80000000};
                else
                    rb = {$urandom(), $urandom()} >> 32;

                op  = $urandom_range(0, 9);   // uniform over all 10 ops
                exp = ref_alu(ra, rb, op);

                a      = ra;
                b      = rb;
                alu_op = op;
                #5;
                total = total + 1;

                if (result !== exp) begin
                    $display("FAIL [random %0d] a=%h b=%h op=%b | got=%h expected=%h",
                             i, ra, rb, op, result, exp);
                    failed = failed + 1;
                end else begin
                    passed = passed + 1;
                end
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Main
    // ----------------------------------------------------------------
    initial begin
        passed = 0; failed = 0; total = 0;
        a = 0; b = 0; alu_op = 0;

        run_directed;
        run_random;

        $display("\n=== Results: %0d/%0d passed", passed, total);
        if (failed == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILURES: %0d", failed);

        $finish;
    end

    // Optional: dump waveforms for GTKWave
    initial begin
        $dumpfile("sim/tb_alu.vcd");
        $dumpvars(0, tb_alu);
    end

endmodule