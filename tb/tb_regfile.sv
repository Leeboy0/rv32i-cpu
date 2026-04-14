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

  initial
    clk = 0;

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
      if(addr != 0)
      begin
        ref_regs[addr] = data;
      end
    end
  endtask

  function automatic [31:0] ref_read;
    input [4:0] addr;
    ref_read = (addr == 5'b0) ? 32'b0 : ref_regs[addr];
  endfunction

  task automatic write_and_check;
    input [4:0]  waddr;
    input [31:0] wdata;
    input [4:0]  raddr1;
    input [4:0]  raddr2;
    input [63:0] test_num;
    begin
      // Step 1: drive write signals
      rd_addr = waddr;
      rd_data = wdata;
      we      = 1;

      // Step 2: wait for clock edge — write latches here
      @(posedge clk);

      // Step 3: small settle, then drop we
      #1;
      we = 0;

      // Step 4: update reference model
      ref_write(waddr, wdata);

      // Step 5: drive read addresses
      rs1_addr = raddr1;
      rs2_addr = raddr2;
      #1;

      // Step 6: compare and count — fill in the blanks
      total = total + 2;

      if (rs1_data !== ref_read(raddr1))
      begin
        $display("FAIL [%0d] rs1: addr=%0d got=%h expected=%h",
                 test_num, raddr1, rs1_data, ref_read(raddr1));
        failed = failed + 1;
      end
      else
        passed = passed + 1;

      if (rs2_data !== ref_read(raddr2))
      begin
        $display("FAIL [%0d] rs2: addr=%0d got=%h expected=%h",
                 test_num, raddr2, rs2_data, ref_read(raddr2));
        failed = failed + 1;
      end
      else
        passed = passed + 1;
    end
  endtask

  task  apply_reset;
    integer i;
    begin
      // Step 1: assert reset
      rst_n = 0;
      we = 0;

      //step 2: wait 2 cycle
      repeat(2) @(posedge clk);

      //step3: release reset
      #1;
      rst_n = 1;

      //step 4: clear reference model
      for(i = 0; i < 32; i = i + 1)
      begin
        ref_regs[i] = 32'b0;
      end

      //step 5: read all registers and check for 0
      for(i = 0; i < 32; i = i + 1)
      begin
        rs1_addr = i[4:0];
        #1;
        total = total + 1;
        if(rs1_data != 32'b0)
        begin
          $display("FAIL reset: reg[%0d] = %h, expected 0", i, rs1_data);
          failed = failed + 1;
        end
        else
          passed = passed + 1;
      end
    end
  endtask

  //task 8: run_directed task
  task  run_directed_task;
    begin
      $display("\n=== part 1: Directed tests ===");

      //first always reset
      apply_reset;

      //call write and check for each test case
      //write_and_check(waddr, wdata, raddr1, raddr2, test_num)
      write_and_check(5'd1, 32'hDEADBEEF, 5'd1, 5'd0, 1);
      write_and_check(5'd3, 32'hAABBCCDD, 5'd3, 5'd0, 2);  // write reg3
      write_and_check(5'd4, 32'h11223344, 5'd3, 5'd4, 3);  // write reg4, read both
      write_and_check(5'd31, 32'hFFFFFFFF, 5'd31, 5'd0, 4);
      write_and_check(5'd1, 32'h00000001, 5'd1, 5'd0, 5);  
    end
  endtask

  //task 9: run random task
  task run_random;
    integer i;
    logic [4:0] waddr, raddr1, raddr2;
    logic [31:0] wdata;
    begin
      $display("\n=== part 2: Random tests ===");
      apply_reset;
      for(i = 0; i < 200; i = i + 1) begin
        waddr = 5'($urandom % 32);
        wdata = $urandom; 
        raddr1 = 5'($urandom % 32);
        raddr2 = 5'($urandom % 32);
        write_and_check(waddr, wdata, raddr1, raddr2, 64'(i));
      end
    end
  endtask

  //task 10 initial block calling them in order
  initial begin
    passed = 0;
    failed = 0;
    total = 0;

    run_directed_task;
    run_random;

    $display("\n=== Results: %0d/%0d passed, %0d failed ===", passed, total, failed);
    $finish;
  end

  //task 11 $dumpfile / $dumpvars
  initial begin
      $dumpfile("sim/tb_regfile.vcd");
      $dumpvars(0, tb_regfile);
  end
endmodule
