// rv32i_cpu/rtl/alu.sv
// RV32I ALU — supports all operations required by the base integer ISA

module alu (
    input  logic [31:0] a,          // rs1 or PC
    input  logic [31:0] b,          // rs2 or immediate
    input  logic [3:0]  alu_op,     // operation select
    output logic [31:0] result,
    output logic        zero        // branch comparison flag
);

    // ALU operation encodings — matches control unit output directly
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;  // signed less-than
    localparam ALU_SLTU = 4'b0110;  // unsigned less-than
    localparam ALU_SLL  = 4'b0111;  // shift left logical
    localparam ALU_SRL  = 4'b1000;  // shift right logical
    localparam ALU_SRA  = 4'b1001;  // shift right arithmetic

    always_comb begin
        result = 32'b0;  // default: avoid latches

        unique case (alu_op)
            ALU_ADD  : result = a + b;
            ALU_SUB  : result = a - b;
            ALU_AND  : result = a & b;
            ALU_OR   : result = a | b;
            ALU_XOR  : result = a ^ b;
            ALU_SLT  : result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU : result = (a < b)                   ? 32'd1 : 32'd0;
            ALU_SLL  : result = a << b[4:0];   // only low 5 bits used per spec
            ALU_SRL  : result = a >> b[4:0];
            ALU_SRA  : result = $signed(a) >>> b[4:0];
            default  : result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);

endmodule