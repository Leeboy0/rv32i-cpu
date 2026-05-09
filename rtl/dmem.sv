// rv32i_cpu/rtl/dmem.sv
// Data memory with byte-addressable load/store.
// - Combinational read with sign/zero extension based on funct3.
// - Synchronous write with byte enables.
//
// funct3 encoding:
//   LOAD : 000 LB   001 LH   010 LW   100 LBU  101 LHU
//   STORE: 000 SB   001 SH   010 SW
//
// Misaligned accesses are NOT trapped — riscv-tests rv32ui programs
// only use aligned access for the supported funct3 values.

module dmem #(
    parameter int DEPTH = 4096      // number of 32-bit words
) (
    input  logic        clk,
    input  logic        we,         // write enable
    input  logic [31:0] addr,       // byte address
    input  logic [31:0] wdata,      // raw rs2 data (sub-word slicing handled here)
    input  logic [2:0]  funct3,     // size + sign for both load and store
    output logic [31:0] rdata
);

    localparam int IDX_W = $clog2(DEPTH);

    logic [31:0] mem [0:DEPTH-1];

    // Initialize to zero so x's don't propagate during simulation
    initial for (int i = 0; i < DEPTH; i++) mem[i] = 32'h0;

    // ---------- Address decode ----------
    wire [IDX_W-1:0] word_idx = addr[IDX_W+1 : 2];
    wire [1:0]       byte_off = addr[1:0];

    // ---------- Read path (combinational) ----------
    logic [31:0] word;
    logic [7:0]  rb;
    logic [15:0] rh;

    always_comb begin
        word = mem[word_idx];

        // Byte select within the word
        unique case (byte_off)
            2'b00  : rb = word[7:0];
            2'b01  : rb = word[15:8];
            2'b10  : rb = word[23:16];
            2'b11  : rb = word[31:24];
            default: rb = 8'b0;
        endcase

        // Halfword select — only offsets 0 and 2 are well-defined
        rh = byte_off[1] ? word[31:16] : word[15:0];

        unique case (funct3)
            3'b000  : rdata = {{24{rb[7]}}, rb};        // LB  (sign-extend)
            3'b001  : rdata = {{16{rh[15]}}, rh};       // LH  (sign-extend)
            3'b010  : rdata = word;                     // LW
            3'b100  : rdata = {24'b0, rb};              // LBU (zero-extend)
            3'b101  : rdata = {16'b0, rh};              // LHU (zero-extend)
            default : rdata = word;                     // safe default
        endcase
    end

    // ---------- Write path (synchronous, byte-enabled) ----------
    // Build the new word combinationally from the old word + wdata, commit on clock.
    logic [31:0] write_word;

    always_comb begin
        write_word = word;  // start from the current value

        unique case (funct3)
            3'b000: begin   // SB
                unique case (byte_off)
                    2'b00  : write_word[7:0]   = wdata[7:0];
                    2'b01  : write_word[15:8]  = wdata[7:0];
                    2'b10  : write_word[23:16] = wdata[7:0];
                    2'b11  : write_word[31:24] = wdata[7:0];
                    default: ;
                endcase
            end
            3'b001: begin   // SH
                if (byte_off[1]) write_word[31:16] = wdata[15:0];
                else             write_word[15:0]  = wdata[15:0];
            end
            3'b010: begin   // SW
                write_word = wdata;
            end
            default: ;      // unrecognized funct3 — leave word untouched
        endcase
    end

    always_ff @(posedge clk) begin
        if (we) mem[word_idx] <= write_word;
    end

endmodule