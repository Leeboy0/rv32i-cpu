// rv32i_cpu/rtl/cpu.sv
// RV32I 5-stage pipelined CPU: IF → ID → EX → MEM → WB
//
// Hazard handling:
//   Load-use:    1-cycle stall (hold PC + IF/ID, insert NOP in ID/EX)
//   Branch/jump: 2-cycle flush (IF/ID + ID/EX → NOP) resolved in EX
//
// Forwarding: EX/MEM → EX operands, MEM/WB → EX operands (EX/MEM has priority)
//
// Memory layout: Harvard (separate imem / dmem at 0x0000_0000)

module cpu #(
    parameter int IMEM_DEPTH = 4096,
    parameter int DMEM_DEPTH = 4096,
    parameter        HEX_FILE   = "sim/program.hex"
) (
    input  logic clk,
    input  logic rst_n,
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_instr
);

    // ================================================================
    //  IF — Instruction Fetch
    // ================================================================
    logic [31:0] pc, pc_next;
    logic [31:0] if_instr;

    assign dbg_pc    = pc;
    assign dbg_instr = if_instr;

    imem #(.DEPTH(IMEM_DEPTH), .HEX_FILE(HEX_FILE)) u_imem (
        .addr  (pc),
        .instr (if_instr)
    );

    // ================================================================
    //  IF/ID pipeline register
    // ================================================================
    logic [31:0] if_id_pc, if_id_instr;

    // ================================================================
    //  ID — Decode / Register Read
    // ================================================================
    wire [6:0] id_opcode = if_id_instr[6:0];
    wire [4:0] id_rd     = if_id_instr[11:7];
    wire [2:0] id_funct3 = if_id_instr[14:12];
    wire [4:0] id_rs1    = if_id_instr[19:15];
    wire [4:0] id_rs2    = if_id_instr[24:20];
    wire [6:0] id_funct7 = if_id_instr[31:25];

    logic       id_reg_we, id_mem_we, id_alu_src_a, id_alu_src_b;
    logic [3:0] id_alu_op;
    logic [1:0] id_wb_sel;
    logic       id_is_branch, id_is_jump, id_is_jalr;
    logic [31:0] id_imm, id_rs1_data, id_rs2_data;

    // ================================================================
    //  ID/EX pipeline register
    // ================================================================
    logic [31:0] id_ex_pc, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
    logic [4:0]  id_ex_rd, id_ex_rs1, id_ex_rs2;
    logic [2:0]  id_ex_funct3;
    logic        id_ex_reg_we, id_ex_mem_we, id_ex_alu_src_a, id_ex_alu_src_b;
    logic [3:0]  id_ex_alu_op;
    logic [1:0]  id_ex_wb_sel;
    logic        id_ex_is_branch, id_ex_is_jump, id_ex_is_jalr;

    // ================================================================
    //  EX/MEM pipeline register
    // ================================================================
    logic [31:0] ex_mem_alu_result, ex_mem_rs2_data, ex_mem_pc_plus4, ex_mem_imm;
    logic [4:0]  ex_mem_rd;
    logic [2:0]  ex_mem_funct3;
    logic        ex_mem_reg_we, ex_mem_mem_we;
    logic [1:0]  ex_mem_wb_sel;

    // ================================================================
    //  MEM/WB pipeline register
    // ================================================================
    logic [31:0] mem_wb_alu_result, mem_wb_dmem_rdata, mem_wb_pc_plus4, mem_wb_imm;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_reg_we;
    logic [1:0]  mem_wb_wb_sel;

    // ================================================================
    //  WB — Writeback mux
    // ================================================================
    logic [31:0] wb_rd_data;

    always_comb begin
        unique case (mem_wb_wb_sel)
            2'b00  : wb_rd_data = mem_wb_alu_result;
            2'b01  : wb_rd_data = mem_wb_dmem_rdata;
            2'b10  : wb_rd_data = mem_wb_pc_plus4;
            2'b11  : wb_rd_data = mem_wb_imm;
            default: wb_rd_data = mem_wb_alu_result;
        endcase
    end

    // ================================================================
    //  EX forwarded operands (declared before use in hazard + pc_next)
    // ================================================================
    logic [31:0] ex_rs1_fwd, ex_rs2_fwd;

    // ================================================================
    //  Hazard detection
    // ================================================================
    logic load_use_stall, ctrl_flush;
    logic ex_take_branch;

    // Load in EX writes a register read in ID this cycle → stall 1 cycle
    assign load_use_stall = (id_ex_wb_sel == 2'b01) && id_ex_reg_we &&
                            (id_ex_rd != 5'b0) &&
                            ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2));

    // Branch/jump resolved in EX → flush the 2 speculatively-fetched instructions
    assign ctrl_flush = ex_take_branch || id_ex_is_jump;

    // ================================================================
    //  Next-PC
    // ================================================================
    always_comb begin
        if (id_ex_is_jalr)
            pc_next = (ex_rs1_fwd + id_ex_imm) & ~32'h1;    // JALR: (rs1+imm)&~1
        else if (ctrl_flush)
            pc_next = id_ex_pc + id_ex_imm;                 // JAL or taken branch
        else
            pc_next = pc + 32'd4;
    end

    // ================================================================
    //  PC register
    // ================================================================
    always_ff @(posedge clk) begin
        if (!rst_n)
            pc <= 32'h0;
        else if (!load_use_stall)
            pc <= pc_next;
    end

    // ================================================================
    //  IF/ID register
    // ================================================================
    always_ff @(posedge clk) begin
        if (!rst_n || ctrl_flush) begin
            if_id_pc    <= 32'h0;
            if_id_instr <= 32'h0;   // all-zero opcode → no-op (control defaults safe)
        end else if (!load_use_stall) begin
            if_id_pc    <= pc;
            if_id_instr <= if_instr;
        end
        // else: hold on load_use_stall
    end

    // ================================================================
    //  Submodules: control, regfile, imm_gen  (in ID stage)
    // ================================================================
    control u_control (
        .opcode    (id_opcode),
        .funct3    (id_funct3),
        .funct7    (id_funct7),
        .reg_we    (id_reg_we),
        .mem_we    (id_mem_we),
        .alu_src_a (id_alu_src_a),
        .alu_src_b (id_alu_src_b),
        .alu_op    (id_alu_op),
        .wb_sel    (id_wb_sel),
        .is_branch (id_is_branch),
        .is_jump   (id_is_jump),
        .is_jalr   (id_is_jalr)
    );

    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (id_rs1),
        .rs2_addr (id_rs2),
        .rd_addr  (mem_wb_rd),
        .rd_data  (wb_rd_data),
        .we       (mem_wb_reg_we),
        .rs1_data (id_rs1_data),
        .rs2_data (id_rs2_data)
    );

    imm_gen u_imm_gen (
        .instr (if_id_instr),
        .imm   (id_imm)
    );

    // ================================================================
    //  ID/EX register
    // ================================================================
    always_ff @(posedge clk) begin
        if (!rst_n || ctrl_flush || load_use_stall) begin
            id_ex_pc        <= 32'h0;
            id_ex_rs1_data  <= 32'h0;
            id_ex_rs2_data  <= 32'h0;
            id_ex_imm       <= 32'h0;
            id_ex_rd        <= 5'h0;
            id_ex_rs1       <= 5'h0;
            id_ex_rs2       <= 5'h0;
            id_ex_funct3    <= 3'h0;
            id_ex_reg_we    <= 1'b0;
            id_ex_mem_we    <= 1'b0;
            id_ex_alu_src_a <= 1'b0;
            id_ex_alu_src_b <= 1'b0;
            id_ex_alu_op    <= 4'h0;
            id_ex_wb_sel    <= 2'b00;
            id_ex_is_branch <= 1'b0;
            id_ex_is_jump   <= 1'b0;
            id_ex_is_jalr   <= 1'b0;
        end else begin
            id_ex_pc        <= if_id_pc;
            id_ex_rs1_data  <= id_rs1_data;
            id_ex_rs2_data  <= id_rs2_data;
            id_ex_imm       <= id_imm;
            id_ex_rd        <= id_rd;
            id_ex_rs1       <= id_rs1;
            id_ex_rs2       <= id_rs2;
            id_ex_funct3    <= id_funct3;
            id_ex_reg_we    <= id_reg_we;
            id_ex_mem_we    <= id_mem_we;
            id_ex_alu_src_a <= id_alu_src_a;
            id_ex_alu_src_b <= id_alu_src_b;
            id_ex_alu_op    <= id_alu_op;
            id_ex_wb_sel    <= id_wb_sel;
            id_ex_is_branch <= id_is_branch;
            id_ex_is_jump   <= id_is_jump;
            id_ex_is_jalr   <= id_is_jalr;
        end
    end

    // ================================================================
    //  EX — Execute: forwarding muxes + ALU + branch unit
    // ================================================================

    // Forwarded result from EX/MEM (for JAL/JALR wb_sel=10, forward pc_plus4)
    logic [31:0] ex_mem_fwd_val;
    always_comb begin
        case (ex_mem_wb_sel)
            2'b10  : ex_mem_fwd_val = ex_mem_pc_plus4;
            2'b11  : ex_mem_fwd_val = ex_mem_imm;
            default: ex_mem_fwd_val = ex_mem_alu_result;
            // wb_sel==01 (load) never reaches here: load-use stall prevents it
        endcase
    end

    // RS1 forwarding: EX/MEM takes priority over MEM/WB
    always_comb begin
        if (ex_mem_reg_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
            ex_rs1_fwd = ex_mem_fwd_val;
        else if (mem_wb_reg_we && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1))
            ex_rs1_fwd = wb_rd_data;
        else
            ex_rs1_fwd = id_ex_rs1_data;
    end

    // RS2 forwarding
    always_comb begin
        if (ex_mem_reg_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
            ex_rs2_fwd = ex_mem_fwd_val;
        else if (mem_wb_reg_we && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2))
            ex_rs2_fwd = wb_rd_data;
        else
            ex_rs2_fwd = id_ex_rs2_data;
    end

    logic [31:0] alu_a, alu_b, ex_alu_result;
    assign alu_a = id_ex_alu_src_a ? id_ex_pc  : ex_rs1_fwd;
    assign alu_b = id_ex_alu_src_b ? id_ex_imm : ex_rs2_fwd;

    /* verilator lint_off UNUSED */
    logic alu_zero_unused;
    /* verilator lint_on UNUSED */

    alu u_alu (
        .a       (alu_a),
        .b       (alu_b),
        .alu_op  (id_ex_alu_op),
        .result  (ex_alu_result),
        .zero    (alu_zero_unused)
    );

    branch_unit u_branch (
        .rs1_data    (ex_rs1_fwd),
        .rs2_data    (ex_rs2_fwd),
        .funct3      (id_ex_funct3),
        .is_branch   (id_ex_is_branch),
        .take_branch (ex_take_branch)
    );

    // ================================================================
    //  EX/MEM register
    // ================================================================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 32'h0;
            ex_mem_rs2_data   <= 32'h0;
            ex_mem_pc_plus4   <= 32'h0;
            ex_mem_imm        <= 32'h0;
            ex_mem_rd         <= 5'h0;
            ex_mem_funct3     <= 3'h0;
            ex_mem_reg_we     <= 1'b0;
            ex_mem_mem_we     <= 1'b0;
            ex_mem_wb_sel     <= 2'b00;
        end else begin
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_rs2_data   <= ex_rs2_fwd;        // forwarded value used by stores
            ex_mem_pc_plus4   <= id_ex_pc + 32'd4;
            ex_mem_imm        <= id_ex_imm;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_funct3     <= id_ex_funct3;
            ex_mem_reg_we     <= id_ex_reg_we;
            ex_mem_mem_we     <= id_ex_mem_we;
            ex_mem_wb_sel     <= id_ex_wb_sel;
        end
    end

    // ================================================================
    //  MEM — Data Memory Access
    // ================================================================
    logic [31:0] mem_dmem_rdata;

    dmem #(.DEPTH(DMEM_DEPTH)) u_dmem (
        .clk    (clk),
        .we     (ex_mem_mem_we),
        .addr   (ex_mem_alu_result),
        .wdata  (ex_mem_rs2_data),
        .funct3 (ex_mem_funct3),
        .rdata  (mem_dmem_rdata)
    );

    // ================================================================
    //  MEM/WB register
    // ================================================================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mem_wb_alu_result <= 32'h0;
            mem_wb_dmem_rdata <= 32'h0;
            mem_wb_pc_plus4   <= 32'h0;
            mem_wb_imm        <= 32'h0;
            mem_wb_rd         <= 5'h0;
            mem_wb_reg_we     <= 1'b0;
            mem_wb_wb_sel     <= 2'b00;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_dmem_rdata <= mem_dmem_rdata;
            mem_wb_pc_plus4   <= ex_mem_pc_plus4;
            mem_wb_imm        <= ex_mem_imm;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_we     <= ex_mem_reg_we;
            mem_wb_wb_sel     <= ex_mem_wb_sel;
        end
    end

endmodule
