`timescale 1ns/1ps

module tb_imm_gen;
    //port declarations
    logic [31:0]    instr;
    logic [31:0]    imm;
    integer passed, failed, total;

    //DUT
    imm_gen dut (
        .instr(instr),
        .imm(imm)
    );

    //reference model
    function automatic [31:0] ref_imm;
        input [31:0] inst;
        case (inst[6:0])
            7'b0010011,
            7'b0000011,
            7'b1100111: ref_imm = {{20{inst[31]}}, inst[31:20]};

            7'b0100011: ref_imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

            7'b1100011: ref_imm = {{19{inst[31]}}, inst[31], inst[7],
                              inst[30:25], inst[11:8], 1'b0};

            7'b0110111,
            7'b0010111: ref_imm = {inst[31:12], 12'b0};

            7'b1101111: ref_imm = {{11{inst[31]}}, inst[31], inst[19:12],
                              inst[20], inst[30:21], 1'b0};

            default:    ref_imm = 32'b0; 
        endcase
    endfunction

    //check task
    task automatic check;
        input [31:0]    test_instr;
        input [31:0]    expected;
        input [255:0]   label;  //string label for diaplay

        begin
            instr = test_instr;
            #1;
            total = total + 1;
            if(imm != expected) begin
                $display("FAIL [%0s]: instr = %h got = %h expected = %h",
                label, test_instr, imm, expected);
                failed = failed + 1;
            end else
                passed = passed + 1;
        end
    endtask //automatic
    
    //instructions builders
    function automatic [31:0] build_i;
        input [11:0]    immval;
        input [6:0]     opcode;
        build_i = {immval, 5'd0, 3'd0, 5'd0, opcode};
    endfunction

    function automatic [31:0] build_s;
        input [11:0]    immval;
        build_s = {immval[11:5], 5'd0, 5'd0, 3'd0, immval[4:0], 7'b0100011};
    endfunction

    function automatic [31:0] build_b;
        input [12:0]    immval; //13 bits, and bit 0 is always 0
        build_b = {immval[12], immval[10:5], 5'd0, 5'd0, 3'd0, immval[4:1], immval[11], 7'b1100011};
    endfunction

    function automatic [31:0] build_u;
        input [19:0]    immval;
        input [6:0]     opcode;
        build_u = {immval, 5'd0, opcode};
    endfunction

    function automatic [31:0] build_j;
        input [20:0]    immval; //21bits amd bit 0 is always 0
        build_j = {immval[20], immval[10:1], immval[11], immval[19:12], 5'd0, 7'b1101111};
    endfunction

    //Directed tests
    task run_directed;
        begin
            $display("===Directed Tests===");
            //I-type :addi
            check(build_i(12'd100, 7'b0010011),     32'd100,        "I + 100");
            check(build_i(-12'd4, 7'b0010011),      32'hFFFFFFFC,   "I -4");
            check(build_i(12'd0, 7'b0010011),       32'd0,          "zero");
            check(build_i(12'h7FF, 7'b0010011),     32'd2047,       "I max pos");
            check(build_i(12'h800, 7'b0010011),     32'hFFFFF800,   "I min neg");

            //I-type: load
            check(build_i(12'd8, 7'b00000011),      32'd8,          "I load +8");
            check(build_i(-12'd8, 7'b00000011),     32'hFFFFFFF8,          "I load -8");

            //S-type
            check(build_s(12'd100),              32'd100,            "S +100");
            check(build_s(-12'd4),               32'hFFFFFFFC,       "S -4");
            check(build_s(12'd0),                32'd0,              "S zero");

            //B-type(Use even value because bit 0 is 0)
            check(build_b(13'd8),               32'd8,              "B +8");
            check(build_b(-13'd8),              32'hFFFFFFF8,        "B -8");
            check(build_b(13'd0),               32'd0,              "B zero");

            //U-type: lui
            check(build_u(20'hABCDE, 7'b0110111), 32'hABCDE000,     "U lui");
            check(build_u(20'h00001, 7'b0110111), 32'h00001000,     "U lui small");
            check(build_u(20'hFFFFF, 7'b0110111), 32'hFFFFF000,     "U lui max");

            // U-type: auipc
            check(build_u(20'h12345, 7'b0010111), 32'h12345000,     "U auipc");

            // J-type (bit 0 always 0, so use even values)
            check(build_j(21'd100),              32'd100,            "J +100");
            check(build_j(-21'd100),             32'hFFFFFF9C,       "J -100");
            check(build_j(21'd0),               32'd0,              "J zero");
        end
        
    endtask //automatic

    //Random Tests
    task run_random;
        integer i;
        logic [31:0] rand_instr;
        logic [6:0]  opcodes [7:0];
        logic [6:0]  rand_op;

        begin
            $display("\n=== Part 2: Random tests ===");

            //Inititalize opcodes to pick from
            opcodes[0] = 7'b0010011;  // I: alu imm;
            opcodes[1] = 7'b0000011;  //I: load
            opcodes[2] = 7'b1100111;  // I: jalr
            opcodes[3] = 7'b0100011;  // S: store
            opcodes[4] = 7'b1100011;  // B: branch
            opcodes[5] = 7'b0110111;  // U: lui
            opcodes[6] = 7'b0010111;  // U: auipc
            opcodes[7] = 7'b1101111;  // J: jal
        end
        
        for(i = 0; i < 500; i = i + 1) begin
            //Pick a random opcode
            rand_op = opcodes[$urandom % 8];

            //Generate random instruction
            rand_instr = $urandom;
            rand_instr[6:0] = rand_op;

            instr = rand_instr;
            #1;
            total = total + 1;
            if(imm !== ref_imm(rand_instr)) begin
                $display("FAIL [rand %0d]: op=%b instr=%h got=%h expected=%h",
                i, rand_op, rand_instr, imm, ref_imm(rand_instr));
                failed = failed + 1;
            end else
                passed = passed + 1;
        end

    endtask //automatic

    //Run tests
    initial begin
        passed = 0;
        failed = 0;
        total  = 0;

        run_directed;
        run_random;
        
        $display("\n=== Results: %0d/%0d passed, %0d failed ===",
        passed, total, failed);
        $finish;
    end

    //Waveform
    initial begin
        $dumpfile("sim/tb_imm_gen.vcd");
        $dumpvars(0, tb_imm_gen);
    end



endmodule
