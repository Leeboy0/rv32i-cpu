// rv32i_cpu/rtl/imem.sv
// Instruction memory — combinational, read-only.
// Word-addressable internally; PC is byte-addressable, so drop the low 2 bits.
// Loads contents from a hex file via $readmemh (see HEX_FILE parameter).

module imem #(
    parameter int    DEPTH    = 4096,            // number of 32-bit words
    parameter        HEX_FILE = "program.hex"     // initial contents
) (
    input  logic [31:0] addr,        // byte address (PC)
    output logic [31:0] instr
);

    localparam int IDX_W = $clog2(DEPTH);   // index width in words

    logic [31:0] mem [0:DEPTH-1];

    // Initial contents.
    // Default to all-zero. If HEX_FILE is non-empty, $readmemh fills the array.
    // (A zero word is an illegal instruction, but riscv-tests programs always
    //  fill the .text region they actually execute.)
    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = 32'h0000_0000;
        if (HEX_FILE != "") $readmemh(HEX_FILE, mem);
    end

    // Byte address -> word index. Drop bits [1:0]; mask above IDX_W to wrap
    // gracefully if a stray PC value goes out of range.
    wire [IDX_W-1:0] word_idx = addr[IDX_W+1 : 2];

    assign instr = mem[word_idx];

endmodule