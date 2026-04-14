// rv32i_cpu/rtl/regfile.sv
// RV32I register file
// - 32 x 32-bit registers
// - 2 combinational read ports (rs1, rs2)
// - 1 synchronous write port (rd)
// - x0 hardwired to zero

module regfile (
    input  logic        clk,
    input  logic        rst_n,       // active-low synchronous reset
    input  logic [4:0]  rs1_addr,    // read port 1 address
    input  logic [4:0]  rs2_addr,    // read port 2 address
    input  logic [4:0]  rd_addr,     // write port address
    input  logic [31:0] rd_data,     // write data
    input  logic        we,          // write enable
    output logic [31:0] rs1_data,    // read port 1 data
    output logic [31:0] rs2_data     // read port 2 data
);

    // 32 registers x 32 bits
    logic [31:0] regs [31:0];

    // ----------------------------------------------------------------
    // Synchronous write — clocked, with active-low reset
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers to zero
            integer i;
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (we && rd_addr != 5'b0) begin
            // Write only if enabled and not targeting x0
            regs[rd_addr] <= rd_data;
        end
    end

    // ----------------------------------------------------------------
    // Combinational read — x0 always returns zero
    // ----------------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : regs[rs2_addr];

endmodule
