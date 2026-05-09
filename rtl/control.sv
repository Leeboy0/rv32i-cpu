// rv32i_cpu/rtl/control.sv
// RV32I control unit — decodes opcode/funct3/funct7 into datapath control signals.
//
// ALU op encoding matches alu.sv exactly:
//   ADD=0 SUB=1 AND=2 OR=3 XOR=4 SLT=5 SLTU=6 SLL=7 SRL=8 SRA=9
//
// Writeback mux (wb_sel):
//   00 = ALU result
//   01 = memory load data
//   10 = PC + 4              (JAL, JALR)
//   11 = immediate (LUI)
//
// ALU operand A select (alu_src_a):  0 = rs1,  1 = PC
// ALU operand B select (alu_src_b):  0 = rs2,  1 = imm

module control (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic       reg_we,
    output logic       mem_we,
    output logic       alu_src_a,
    output logic       alu_src_b,
    output logic [3:0] alu_op,
    output logic [1:0] wb_sel,
    output logic       is_branch,
    output logic       is_jump,
    output logic       is_jalr
  );

  // ---------------- Opcode constants (RV32I) ----------------
  localparam OP_LUI    = 7'b0110111;
  localparam OP_AUIPC  = 7'b0010111;
  localparam OP_JAL    = 7'b1101111;
  localparam OP_JALR   = 7'b1100111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_LOAD   = 7'b0000011;
  localparam OP_STORE  = 7'b0100011;
  localparam OP_IMM    = 7'b0010011;  // ADDI/SLTI/.../SRAI
  localparam OP_REG    = 7'b0110011;  // ADD/SUB/.../AND

  // ---------------- ALU op constants (match alu.sv) ----------
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

  // ---------------- Main decode ----------------
  always_comb
  begin
    // Safe defaults — prevent latches and stop spurious writes
    reg_we    = 1'b0;
    mem_we    = 1'b0;
    alu_src_a = 1'b0;       // rs1
    alu_src_b = 1'b0;       // rs2
    alu_op    = ALU_ADD;
    wb_sel    = 2'b00;      // ALU
    is_branch = 1'b0;
    is_jump   = 1'b0;
    is_jalr   = 1'b0;

    unique case (opcode)
             // ---------- LUI: rd = imm ----------
             OP_LUI:
             begin
               reg_we = 1'b1;
               wb_sel = 2'b11;     // immediate
             end

             // ---------- AUIPC: rd = PC + imm ----------
             OP_AUIPC:
             begin
               reg_we    = 1'b1;
               alu_src_a = 1'b1;   // PC
               alu_src_b = 1'b1;   // imm
               alu_op    = ALU_ADD;
               wb_sel    = 2'b00;  // ALU
             end

             // ---------- JAL: rd = PC+4; PC = PC + imm ----------
             OP_JAL:
             begin
               reg_we  = 1'b1;
               wb_sel  = 2'b10;    // PC+4
               is_jump = 1'b1;
             end

             // ---------- JALR: rd = PC+4; PC = (rs1 + imm) & ~1 ----------
             OP_JALR:
             begin
               reg_we    = 1'b1;
               alu_src_a = 1'b0;   // rs1
               alu_src_b = 1'b1;   // imm
               alu_op    = ALU_ADD;
               wb_sel    = 2'b10;  // PC+4
               is_jump   = 1'b1;
               is_jalr   = 1'b1;
             end

             // ---------- BRANCH: compare rs1, rs2; PC += imm if taken ----------
             OP_BRANCH:
             begin
               is_branch = 1'b1;
               // No reg/mem writes; ALU not used for branch decision.
             end

             // ---------- LOAD: rd = MEM[rs1+imm] ----------
             OP_LOAD:
             begin
               reg_we    = 1'b1;
               alu_src_a = 1'b0;   // rs1
               alu_src_b = 1'b1;   // imm
               alu_op    = ALU_ADD;
               wb_sel    = 2'b01;  // memory
             end

             // ---------- STORE: MEM[rs1+imm] = rs2 ----------
             OP_STORE:
             begin
               mem_we    = 1'b1;
               alu_src_a = 1'b0;
               alu_src_b = 1'b1;
               alu_op    = ALU_ADD;
             end

             // ---------- OP-IMM: ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI ----------
             OP_IMM:
             begin
               reg_we    = 1'b1;
               alu_src_a = 1'b0;
               alu_src_b = 1'b1;   // imm
               wb_sel    = 2'b00;
               unique case (funct3)
                 3'b000  :
                   alu_op = ALU_ADD;     // ADDI
                 3'b010  :
                   alu_op = ALU_SLT;     // SLTI
                 3'b011  :
                   alu_op = ALU_SLTU;    // SLTIU
                 3'b100  :
                   alu_op = ALU_XOR;     // XORI
                 3'b110  :
                   alu_op = ALU_OR;      // ORI
                 3'b111  :
                   alu_op = ALU_AND;     // ANDI
                 3'b001  :
                   alu_op = ALU_SLL;     // SLLI
                 3'b101  :
                   alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRAI/SRLI
                 default :
                   alu_op = ALU_ADD;
               endcase
             end

             // ---------- OP: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND ----------
             OP_REG:
             begin
               reg_we    = 1'b1;
               alu_src_a = 1'b0;
               alu_src_b = 1'b0;   // rs2
               wb_sel    = 2'b00;
               unique case (funct3)
                 3'b000  :
                   alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;  // SUB/ADD
                 3'b001  :
                   alu_op = ALU_SLL;
                 3'b010  :
                   alu_op = ALU_SLT;
                 3'b011  :
                   alu_op = ALU_SLTU;
                 3'b100  :
                   alu_op = ALU_XOR;
                 3'b101  :
                   alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;  // SRA/SRL
                 3'b110  :
                   alu_op = ALU_OR;
                 3'b111  :
                   alu_op = ALU_AND;
                 default :
                   alu_op = ALU_ADD;
               endcase
             end

             default:
             begin
               // Unknown opcode — keep all writes disabled.
             end
           endcase
         end

endmodule
