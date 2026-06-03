// uvm/cpu_pkg.sv — RV32I CPU UVM environment
//
// Class hierarchy:
//   cpu_prog_item       sequence item (program to load + run duration)
//   cpu_reg_trans       monitor output (one register-write event)
//   rv32i_ref_model     embedded ISA interpreter (not a UVM class)
//   cpu_driver          loads imem, drives rst_n
//   cpu_monitor         diffs regfile mirror every cycle → cpu_reg_trans
//   cpu_scoreboard      runs ref model on-demand, compares write sequences
//   cpu_coverage        ISA opcode + hazard covergroups
//   cpu_agent           sequencer + driver + monitor
//   cpu_env             agent + scoreboard + coverage
//   cpu_base_test       base test (builds env)
//   cpu_smoke_test      directed 5+3=8 test
//   cpu_hazard_test     load-use + forwarding stress test

package cpu_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Two analysis-imp tags for the scoreboard's dual inputs
    `uvm_analysis_imp_decl(_prog)   // cpu_prog_item (from driver)
    `uvm_analysis_imp_decl(_trans)  // cpu_reg_trans  (from monitor)

    // ================================================================
    //  cpu_prog_item — stimulus: a program + run length
    // ================================================================
    class cpu_prog_item extends uvm_sequence_item;
        `uvm_object_utils(cpu_prog_item)

        // Program words to load into imem (index 0 = address 0x00000000)
        logic [31:0] imem [0:63];
        int unsigned prog_len;      // number of valid words
        int unsigned run_cycles;    // cycles to run after reset deasserts

        function new(string name = "cpu_prog_item");
            super.new(name);
            prog_len   = 0;
            run_cycles = 50;
        endfunction
    endclass

    // ================================================================
    //  cpu_reg_trans — observed register-write retirement event
    // ================================================================
    class cpu_reg_trans extends uvm_sequence_item;
        `uvm_object_utils(cpu_reg_trans)

        logic [4:0]  rd;       // register written (1..31)
        logic [31:0] rd_val;   // new value
        int unsigned cycle;    // for debug logging

        function new(string name = "cpu_reg_trans");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("cyc=%0d  x%0d = %08h", cycle, rd, rd_val);
        endfunction
    endclass

    // ================================================================
    //  rv32i_ref_model — stand-alone ISA interpreter (not a UVM class)
    //
    //  Call reset() + load_imem() before each test program.
    //  Call step() once per expected register write; it advances the
    //  model until it produces a non-x0 register write and returns it.
    // ================================================================
    class rv32i_ref_model;

        logic [31:0] regs [0:31];
        logic [31:0] imem [0:4095];
        logic [31:0] dmem [0:4095];
        logic [31:0] pc;

        function void reset();
            foreach (regs[i]) regs[i] = '0;
            foreach (dmem[i]) dmem[i] = '0;
            pc = '0;
        endfunction

        function void load_imem(logic [31:0] prog [], int unsigned len);
            foreach (imem[i]) imem[i] = '0;
            for (int i = 0; i < int'(len); i++) imem[i] = prog[i];
        endfunction

        // Advance the model until it retires an instruction that writes a
        // non-x0 register.  Returns (wr_rd, wr_val).
        // Caller is responsible for not calling past the end of the program.
        function automatic void next_write(output logic [4:0]  wr_rd,
                                           output logic [31:0] wr_val);
            logic done = 0;
            while (!done) begin
                logic [4:0]  rd;
                logic [31:0] val;
                logic        en;
                execute_one(rd, val, en);
                if (en && rd != 0) begin
                    wr_rd  = rd;
                    wr_val = val;
                    done   = 1;
                end
            end
        endfunction

        // Execute exactly one instruction and optionally report a register write.
        local function automatic void execute_one(
            output logic [4:0]  wr_rd,
            output logic [31:0] wr_val,
            output logic        wr_en
        );
            logic [31:0] instr  = imem[pc[13:2]];   // word-indexed
            logic [6:0]  opcode = instr[6:0];
            logic [4:0]  rd     = instr[11:7];
            logic [2:0]  fn3    = instr[14:12];
            logic [4:0]  rs1    = instr[19:15];
            logic [4:0]  rs2    = instr[24:20];
            logic [6:0]  fn7    = instr[31:25];
            logic [31:0] r1     = (rs1 == 0) ? '0 : regs[rs1];
            logic [31:0] r2     = (rs2 == 0) ? '0 : regs[rs2];

            // Immediate variants
            logic [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
            logic [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            logic [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7],
                                   instr[30:25], instr[11:8], 1'b0};
            logic [31:0] imm_u = {instr[31:12], 12'b0};
            logic [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                                   instr[20], instr[30:21], 1'b0};

            logic [31:0] next_pc = pc + 4;
            wr_en  = 0;
            wr_rd  = rd;
            wr_val = '0;

            case (opcode)
                7'h37: begin wr_en=1; wr_val=imm_u; end                         // LUI
                7'h17: begin wr_en=1; wr_val=pc+imm_u; end                      // AUIPC
                7'h6F: begin wr_en=1; wr_val=pc+4; next_pc=pc+imm_j; end        // JAL
                7'h67: begin wr_en=1; wr_val=pc+4;                              // JALR
                             next_pc=(r1+imm_i)&~32'h1; end
                7'h63: begin                                                     // BRANCH
                    logic taken;
                    case (fn3)
                        3'd0: taken=(r1==r2);       3'd1: taken=(r1!=r2);
                        3'd4: taken=($signed(r1)<$signed(r2));
                        3'd5: taken=($signed(r1)>=$signed(r2));
                        3'd6: taken=(r1<r2);        3'd7: taken=(r1>=r2);
                        default: taken=0;
                    endcase
                    if (taken) next_pc=pc+imm_b;
                end
                7'h03: begin                                                     // LOAD
                    logic [31:0] addr=r1+imm_i;
                    logic [31:0] word=dmem[addr[13:2]];
                    wr_en=1;
                    case (fn3)
                        3'd0: wr_val={{24{word[8*addr[1:0]+7]}}, word[8*addr[1:0]+:8]}; // LB
                        3'd1: wr_val=addr[1] ? {{16{word[31]}},word[31:16]}              // LH
                                             : {{16{word[15]}},word[15:0]};
                        3'd2: wr_val=word;                                               // LW
                        3'd4: wr_val={24'b0,word[8*addr[1:0]+:8]};                      // LBU
                        3'd5: wr_val=addr[1] ? {16'b0,word[31:16]}:{16'b0,word[15:0]}; // LHU
                        default: wr_val=word;
                    endcase
                end
                7'h23: begin                                                     // STORE
                    logic [31:0] addr=r1+imm_s;
                    case (fn3)
                        3'd0: dmem[addr[13:2]][8*addr[1:0]+:8]=r2[7:0];         // SB
                        3'd1: if(addr[1]) dmem[addr[13:2]][31:16]=r2[15:0];     // SH
                              else        dmem[addr[13:2]][15:0] =r2[15:0];
                        3'd2: dmem[addr[13:2]]=r2;                              // SW
                        default: ;
                    endcase
                end
                7'h13: begin                                                     // OP-IMM
                    wr_en=1;
                    case (fn3)
                        3'd0: wr_val=r1+imm_i;
                        3'd1: wr_val=r1<<imm_i[4:0];
                        3'd2: wr_val=($signed(r1)<$signed(imm_i))?1:0;
                        3'd3: wr_val=(r1<imm_i)?1:0;
                        3'd4: wr_val=r1^imm_i;
                        3'd5: wr_val=fn7[5]?($signed(r1)>>>imm_i[4:0]):(r1>>imm_i[4:0]);
                        3'd6: wr_val=r1|imm_i;
                        3'd7: wr_val=r1&imm_i;
                    endcase
                end
                7'h33: begin                                                     // OP
                    wr_en=1;
                    case (fn3)
                        3'd0: wr_val=fn7[5]?r1-r2:r1+r2;
                        3'd1: wr_val=r1<<r2[4:0];
                        3'd2: wr_val=($signed(r1)<$signed(r2))?1:0;
                        3'd3: wr_val=(r1<r2)?1:0;
                        3'd4: wr_val=r1^r2;
                        3'd5: wr_val=fn7[5]?($signed(r1)>>>r2[4:0]):(r1>>r2[4:0]);
                        3'd6: wr_val=r1|r2;
                        3'd7: wr_val=r1&r2;
                    endcase
                end
                default: ; // unknown opcode — no write, advance PC
            endcase

            pc = next_pc;
            if (wr_en && rd != 0) regs[rd] = wr_val;
        endfunction

    endclass : rv32i_ref_model

    // ================================================================
    //  cpu_driver — loads imem via backdoor signals, drives rst_n
    // ================================================================
    class cpu_driver extends uvm_driver #(cpu_prog_item);
        `uvm_component_utils(cpu_driver)

        virtual cpu_if vif;

        // Broadcasts each loaded item to the scoreboard so it can reset
        // its reference model with the same program
        uvm_analysis_port #(cpu_prog_item) prog_ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            prog_ap = new("prog_ap", this);
            if (!uvm_config_db #(virtual cpu_if)::get(this, "", "vif", vif))
                `uvm_fatal("CFG", "cpu_if not found in config DB")
        endfunction

        task run_phase(uvm_phase phase);
            // Idle defaults
            vif.drv_cb.rst_n      <= 0;
            vif.drv_cb.imem_wr_en <= 0;
            @(vif.drv_cb);

            forever begin
                cpu_prog_item item;
                seq_item_port.get_next_item(item);
                drive(item);
                seq_item_port.item_done();
            end
        endtask

        task drive(cpu_prog_item item);
            // 1. Assert reset
            vif.drv_cb.rst_n <= 0;
            repeat (2) @(vif.drv_cb);

            // 2. Backdoor-write program into imem word by word.
            //    tb_top propagates imem_wr_* signals to dut.u_imem.mem.
            for (int i = 0; i < int'(item.prog_len); i++) begin
                vif.drv_cb.imem_wr_addr <= 12'(i);
                vif.drv_cb.imem_wr_data <= item.imem[i];
                vif.drv_cb.imem_wr_en   <= 1;
                @(vif.drv_cb);
            end
            vif.drv_cb.imem_wr_en <= 0;

            // 3. Tell scoreboard which program we just loaded
            prog_ap.write(item);

            // 4. Deassert reset
            repeat (2) @(vif.drv_cb);
            vif.drv_cb.rst_n <= 1;

            // 5. Let CPU run
            repeat (item.run_cycles) @(vif.drv_cb);
        endtask

    endclass : cpu_driver

    // ================================================================
    //  cpu_monitor — diffs the regfile mirror each cycle
    //
    //  Design note: the monitor compares regs[] to a local snapshot.
    //  Any register that changed since the last cycle is reported as a
    //  cpu_reg_trans.  This detects WB-stage retirements without any
    //  DUT modification.
    // ================================================================
    class cpu_monitor extends uvm_monitor;
        `uvm_component_utils(cpu_monitor)

        virtual cpu_if       vif;
        uvm_analysis_port #(cpu_reg_trans) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db #(virtual cpu_if)::get(this, "", "vif", vif))
                `uvm_fatal("CFG", "cpu_if not found in config DB")
        endfunction

        task run_phase(uvm_phase phase);
            logic [31:0] prev_regs [0:31] = '{default: '0};
            int unsigned cyc = 0;

            forever begin
                @(vif.mon_cb);

                if (!vif.mon_cb.rst_n) begin
                    // Reset: clear local snapshot
                    foreach (prev_regs[i]) prev_regs[i] = '0;
                    cyc = 0;
                    continue;
                end
                cyc++;

                // Diff: report every non-x0 register that changed
                for (int i = 1; i < 32; i++) begin
                    if (vif.mon_cb.regs[i] !== prev_regs[i]) begin
                        cpu_reg_trans t = cpu_reg_trans::type_id::create("t");
                        t.rd     = 5'(i);
                        t.rd_val = vif.mon_cb.regs[i];
                        t.cycle  = cyc;
                        ap.write(t);
                        `uvm_info("MON", t.convert2string(), UVM_HIGH)
                    end
                end
                prev_regs = vif.mon_cb.regs;
            end
        endtask

    endclass : cpu_monitor

    // ================================================================
    //  cpu_scoreboard — compares observed write sequences to ISA model
    //
    //  Strategy: run the reference model on-demand.  When the monitor
    //  reports a write (rd, rd_val), advance the ref model until it
    //  also produces a write, then compare.  In-order execution
    //  guarantees the sequences are aligned even across stalls/flushes
    //  (pipeline NOPs produce no writes in either model).
    // ================================================================
    class cpu_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(cpu_scoreboard)

        uvm_analysis_imp_prog  #(cpu_prog_item,  cpu_scoreboard) prog_export;
        uvm_analysis_imp_trans #(cpu_reg_trans,  cpu_scoreboard) trans_export;

        rv32i_ref_model isa_model;
        int unsigned    checks_passed = 0;
        int unsigned    checks_failed = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            prog_export  = new("prog_export",  this);
            trans_export = new("trans_export", this);
            isa_model    = new();
        endfunction

        // Called by driver's prog_ap: reset and reload the ISA model
        function void write_prog(cpu_prog_item item);
            isa_model.reset();
            isa_model.load_imem(item.imem, item.prog_len);
            `uvm_info("SCB", $sformatf("Loaded program (%0d words)", item.prog_len), UVM_MEDIUM)
        endfunction

        // Called for every write event the monitor observes
        function void write_trans(cpu_reg_trans t);
            logic [4:0]  exp_rd;
            logic [31:0] exp_val;

            isa_model.next_write(exp_rd, exp_val);   // advance model to next write

            if (t.rd !== exp_rd || t.rd_val !== exp_val) begin
                `uvm_error("SCB",
                    $sformatf("MISMATCH: DUT x%0d=%08h | REF x%0d=%08h  (cyc %0d)",
                              t.rd, t.rd_val, exp_rd, exp_val, t.cycle))
                checks_failed++;
            end else begin
                `uvm_info("SCB",
                    $sformatf("OK x%0d=%08h  (cyc %0d)", t.rd, t.rd_val, t.cycle),
                    UVM_HIGH)
                checks_passed++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB",
                $sformatf("Scoreboard: %0d PASSED  %0d FAILED",
                          checks_passed, checks_failed),
                UVM_NONE)
            if (checks_failed > 0)
                `uvm_fatal("SCB", "*** TEST FAILED ***")
        endfunction

    endclass : cpu_scoreboard

    // ================================================================
    //  cpu_coverage — functional coverage
    // ================================================================
    class cpu_coverage extends uvm_subscriber #(cpu_reg_trans);
        `uvm_component_utils(cpu_coverage)

        cpu_reg_trans cur;

        // Opcode coverage — the interface observes dbg_instr which is
        // the IF-stage instruction; we track it in the transaction.
        // (Add instr field to cpu_reg_trans if you need per-retirement
        //  opcode tracking; here we use the monitor's cycle count as
        //  a proxy and extend per project needs.)

        covergroup opcode_cg;
            // Extend cpu_reg_trans to carry dbg_instr if needed;
            // shown here as a template coverpoint.
            cp_rd_range: coverpoint cur.rd {
                bins zero       = {0};
                bins low        = {[1:7]};
                bins mid        = {[8:15]};
                bins hi         = {[16:31]};
            }
        endgroup

        // Track consecutive writes to the same register (forwarding path)
        covergroup forwarding_cg;
            cp_rd: coverpoint cur.rd { bins nonzero[] = {[1:31]}; }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            opcode_cg     = new();
            forwarding_cg = new();
        endfunction

        function void write(cpu_reg_trans t);
            cur = t;
            opcode_cg.sample();
            forwarding_cg.sample();
        endfunction

    endclass : cpu_coverage

    // ================================================================
    //  cpu_agent
    // ================================================================
    class cpu_agent extends uvm_agent;
        `uvm_component_utils(cpu_agent)

        uvm_sequencer #(cpu_prog_item) sequencer;
        cpu_driver                     driver;
        cpu_monitor                    monitor;

        // Forwarded from monitor — connect to scoreboard and coverage
        uvm_analysis_port #(cpu_reg_trans) trans_ap;
        // Forwarded from driver — connect to scoreboard
        uvm_analysis_port #(cpu_prog_item) prog_ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = uvm_sequencer #(cpu_prog_item)::type_id::create("sequencer", this);
            driver    = cpu_driver::type_id::create("driver",    this);
            monitor   = cpu_monitor::type_id::create("monitor",  this);
            trans_ap  = new("trans_ap", this);
            prog_ap   = new("prog_ap",  this);
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            monitor.ap.connect(trans_ap);
            driver.prog_ap.connect(prog_ap);
        endfunction

    endclass : cpu_agent

    // ================================================================
    //  cpu_env
    // ================================================================
    class cpu_env extends uvm_env;
        `uvm_component_utils(cpu_env)

        cpu_agent      agent;
        cpu_scoreboard scoreboard;
        cpu_coverage   coverage;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent      = cpu_agent::type_id::create("agent",      this);
            scoreboard = cpu_scoreboard::type_id::create("scoreboard", this);
            coverage   = cpu_coverage::type_id::create("coverage", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agent.trans_ap.connect(scoreboard.trans_export);
            agent.prog_ap.connect(scoreboard.prog_export);
            agent.trans_ap.connect(coverage.analysis_export);
        endfunction

    endclass : cpu_env

    // ================================================================
    //  Sequences
    // ================================================================

    // Smoke test: 5 + 3 = 8 → x3
    class cpu_smoke_seq extends uvm_sequence #(cpu_prog_item);
        `uvm_object_utils(cpu_smoke_seq)
        function new(string name = "cpu_smoke_seq"); super.new(name); endfunction

        task body();
            cpu_prog_item item = cpu_prog_item::type_id::create("item");
            start_item(item);
            item.imem[0]   = 32'h00500093; // addi x1, x0, 5
            item.imem[1]   = 32'h00300113; // addi x2, x0, 3
            item.imem[2]   = 32'h002081B3; // add  x3, x1, x2
            item.imem[3]   = 32'h0000006F; // jal  x0, 0  (loop)
            item.prog_len  = 4;
            item.run_cycles = 30;
            finish_item(item);
        endtask
    endclass

    // Load-use hazard: LW immediately followed by dependent ADD
    class cpu_load_use_seq extends uvm_sequence #(cpu_prog_item);
        `uvm_object_utils(cpu_load_use_seq)
        function new(string name = "cpu_load_use_seq"); super.new(name); endfunction

        task body();
            cpu_prog_item item = cpu_prog_item::type_id::create("item");
            start_item(item);
            item.imem[0]   = 32'h02A00093; // addi x1, x0, 42
            item.imem[1]   = 32'h00102023; // sw   x1, 0(x0)    store 42 → dmem[0]
            item.imem[2]   = 32'h00002103; // lw   x2, 0(x0)    load  42 → x2
            item.imem[3]   = 32'h00210133; // add  x2, x2, x2   ← load-use hazard; expects 84
            item.imem[4]   = 32'h0000006F; // jal  x0, 0
            item.prog_len  = 5;
            item.run_cycles = 40;
            finish_item(item);
        endtask
    endclass

    // EX/MEM forwarding: back-to-back ALU → dependent ALU
    class cpu_fwd_seq extends uvm_sequence #(cpu_prog_item);
        `uvm_object_utils(cpu_fwd_seq)
        function new(string name = "cpu_fwd_seq"); super.new(name); endfunction

        task body();
            cpu_prog_item item = cpu_prog_item::type_id::create("item");
            start_item(item);
            item.imem[0]   = 32'h00A00093; // addi x1, x0, 10
            item.imem[1]   = 32'h00108113; // addi x2, x1,  1   ← MEM/WB forward (x1)
            item.imem[2]   = 32'h00208193; // addi x3, x1,  2   ← MEM/WB forward (x1)
            item.imem[3]   = 32'h002101B3; // add  x3, x2, x2   ← EX/MEM forward (x2)
            item.imem[4]   = 32'h0000006F; // jal  x0, 0
            item.prog_len  = 5;
            item.run_cycles = 40;
            finish_item(item);
        endtask
    endclass

    // ================================================================
    //  Tests
    // ================================================================
    class cpu_base_test extends uvm_test;
        `uvm_component_utils(cpu_base_test)
        cpu_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = cpu_env::type_id::create("env", this);
        endfunction
    endclass

    class cpu_smoke_test extends cpu_base_test;
        `uvm_component_utils(cpu_smoke_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        task run_phase(uvm_phase phase);
            cpu_smoke_seq seq = cpu_smoke_seq::type_id::create("seq");
            phase.raise_objection(this);
            seq.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

    class cpu_hazard_test extends cpu_base_test;
        `uvm_component_utils(cpu_hazard_test)
        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        task run_phase(uvm_phase phase);
            cpu_smoke_seq    smoke = cpu_smoke_seq::type_id::create("smoke");
            cpu_load_use_seq lu    = cpu_load_use_seq::type_id::create("lu");
            cpu_fwd_seq      fwd   = cpu_fwd_seq::type_id::create("fwd");
            phase.raise_objection(this);
            smoke.start(env.agent.sequencer);
            lu.start(env.agent.sequencer);
            fwd.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

endpackage : cpu_pkg
