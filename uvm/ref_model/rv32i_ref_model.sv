// uvm/ref_model/rv32i_ref_model.sv — stand-alone ISA interpreter (not a UVM class)
//
//  Call reset() + load_imem() before each test program.
//  Call step() once per expected register write; it advances the
//  model until it produces a non-x0 register write and returns it.

`ifndef RV32I_REF_MODEL_SV
`define RV32I_REF_MODEL_SV

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

`endif // RV32I_REF_MODEL_SV
