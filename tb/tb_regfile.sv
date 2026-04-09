// rv32i_cpu/tb/tb_regfile.sv
//1. Port declarations (copy from DUT, flip input/output)
//2. ref_regs array
//3. Clock generation
//4. DUT instantiation
//5. ref_write task + ref_read function
//6. check task (write → clock → read → compare)
//7. apply_reset task
//8. run_directed task
//9. run_random task
//10. initial block calling them in order
//11. $dumpfile / $dumpvars

`timescale 1ns/1ps
//test sgnal

module tb_regfile;
    logic clk, we; 
    logic rst_n;
    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rd_data, rs1_data, rs2_data;
    logic [31:0] ref_regs [31:0];
    integer      passed, failed, total;

    initial clk = 0;

    always #5 clk = ~clk;

    regfile dut(
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .we(we)  
    );

    task automatic ref_write;
        input [4:0]     addr;
        input [31:0]    data;
        begin
            if(addr != 0) begin
                ref_regs[addr] = data;  
            end
        end    
    endtask

    function automatic [31:0] ref_read;
        input [4:0] addr;
        ref_read = (addr == 5'b0) ? 32'b0 : ref_regs[addr];        
    endfunction

endmodule
