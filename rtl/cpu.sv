// rv32i_cpu/rtl/cpu.sv
// Single-cycle RV32I CPU — top-level datapath.
//
// Memory layout assumed by tests:
//   imem at 0x0000_0000 (read-only)
//   dmem at 0x0000_0000 (separate space — Harvard architecture for simplicity)
//
// One instruction completes per clock cycle.

module cpu #(
    parameter int    IMEM_DEPTH = 4096,
    parameter int    DMEM_DEPTH = 4096,
    parameter        HEX_FILE   = "program.hex"
) (
    input  logic clk,
    input  logic rst_n,

    // Debug observability — handy for testbench probes & riscv-tests pass/fail
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_instr
);

    // -----------------------------------------------------------
    // Program counter
    // -----------------------------------------------------------
    logic [31:0] pc, pc_next, pc_plus4;

    always_ff @(posedge clk) begin
        if (!rst_n) pc <= 32'h0000_0000;
        else        pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // -----------------------------------------------------------
    // Instruction fetch
    // -----------------------------------------------------------
    logic [31:0] instr;

    imem #(
        .DEPTH    (IMEM_DEPTH),
        .HEX_FILE (HEX_FILE)
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // Common instruction fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // -----------------------------------------------------------
    // Control
    // -----------------------------------------------------------
    logic       reg_we, mem_we;
    logic       alu_src_a, alu_src_b;
    logic [3:0] alu_op;
    logic [1:0] wb_sel;
    logic       is_branch, is_jump, is_jalr;

    control u_control (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .reg_we    (reg_we),
        .mem_we    (mem_we),
        .alu_src_a (alu_src_a),
        .alu_src_b (alu_src_b),
        .alu_op    (alu_op),
        .wb_sel    (wb_sel),
        .is_branch (is_branch),
        .is_jump   (is_jump),
        .is_jalr   (is_jalr)
    );

    // -----------------------------------------------------------
    // Register file
    // -----------------------------------------------------------
    logic [31:0] rs1_data, rs2_data, rd_data;

    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rd_addr  (rd),
        .rd_data  (rd_data),
        .we       (reg_we),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // -----------------------------------------------------------
    // Immediate generation
    // -----------------------------------------------------------
    logic [31:0] imm;

    imm_gen u_imm_gen (
        .instr (instr),
        .imm   (imm)
    );

    // -----------------------------------------------------------
    // ALU + operand muxes
    // -----------------------------------------------------------
    logic [31:0] alu_a, alu_b, alu_result;

    assign alu_a = alu_src_a ? pc       : rs1_data;
    assign alu_b = alu_src_b ? imm      : rs2_data;

    // ALU's `zero` flag is not used at the top level — branch_unit handles
    // all comparisons. Tie it off to a silenced `unused` net.
    /* verilator lint_off UNUSED */
    logic alu_zero_unused;
    /* verilator lint_on UNUSED */

    alu u_alu (
        .a       (alu_a),
        .b       (alu_b),
        .alu_op  (alu_op),
        .result  (alu_result),
        .zero    (alu_zero_unused)
    );

    // -----------------------------------------------------------
    // Branch unit
    // -----------------------------------------------------------
    logic take_branch;

    branch_unit u_branch (
        .rs1_data    (rs1_data),
        .rs2_data    (rs2_data),
        .funct3      (funct3),
        .is_branch   (is_branch),
        .take_branch (take_branch)
    );

    // -----------------------------------------------------------
    // Data memory
    // -----------------------------------------------------------
    logic [31:0] dmem_rdata;

    dmem #(
        .DEPTH (DMEM_DEPTH)
    ) u_dmem (
        .clk    (clk),
        .we     (mem_we),
        .addr   (alu_result),     // address = rs1 + imm
        .wdata  (rs2_data),
        .funct3 (funct3),
        .rdata  (dmem_rdata)
    );

    // -----------------------------------------------------------
    // Writeback mux
    // -----------------------------------------------------------
    always_comb begin
        unique case (wb_sel)
            2'b00  : rd_data = alu_result;     // ALU
            2'b01  : rd_data = dmem_rdata;     // load
            2'b10  : rd_data = pc_plus4;       // JAL/JALR
            2'b11  : rd_data = imm;            // LUI
            default: rd_data = alu_result;
        endcase
    end

    // -----------------------------------------------------------
    // Next-PC logic
    // -----------------------------------------------------------
    // - Branch taken or JAL : pc + imm
    // - JALR                : (rs1 + imm) & ~1
    // - Otherwise           : pc + 4
    logic [31:0] pc_branch, pc_jalr;

    assign pc_branch = pc + imm;
    assign pc_jalr   = (rs1_data + imm) & ~32'b1;   // clear LSB per spec

    always_comb begin
        if      (is_jalr)                pc_next = pc_jalr;
        else if (is_jump || take_branch) pc_next = pc_branch;
        else                             pc_next = pc_plus4;
    end

    // -----------------------------------------------------------
    // Debug taps
    // -----------------------------------------------------------
    assign dbg_pc    = pc;
    assign dbg_instr = instr;

endmodule