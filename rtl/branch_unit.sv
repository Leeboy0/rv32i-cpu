// rv32i_cpu/rtl/branch_unit.sv
// Branch comparison for B-type instructions.
// Produces a single `take_branch` signal based on funct3 of the branch instr.
//
// funct3 encoding (RISC-V spec):
//   000 BEQ   001 BNE
//   100 BLT   101 BGE   (signed)
//   110 BLTU  111 BGEU  (unsigned)

module branch_unit (
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    input  logic [2:0]  funct3,
    input  logic        is_branch,    // gate from control unit
    output logic        take_branch
  );

  logic eq, lt_s, lt_u;

  assign eq   = (rs1_data == rs2_data);
  assign lt_s = ($signed(rs1_data) <  $signed(rs2_data));
  assign lt_u = (rs1_data < rs2_data);

  always_comb
  begin
    unique case (funct3)
             3'b000  :
               take_branch = is_branch &  eq;     // BEQ
             3'b001  :
               take_branch = is_branch & ~eq;     // BNE
             3'b100  :
               take_branch = is_branch &  lt_s;   // BLT
             3'b101  :
               take_branch = is_branch & ~lt_s;   // BGE
             3'b110  :
               take_branch = is_branch &  lt_u;   // BLTU
             3'b111  :
               take_branch = is_branch & ~lt_u;   // BGEU
             default :
               take_branch = 1'b0;
           endcase
         end

endmodule
