/*
* File: Rename.v
* Author: Nikita Kim & Celine Wang
* Email: kimn1944@gmail.com
* Date: 12/10/19
*/

`include "config.v"

module Rename (
    input CLK,
    input RESET,
    input STALL,
    input FLUSH,

    //from decoder
    input [31:0] id_instr,
    input [31:0] id_instrpc,
    input [4:0] id_RegA,
    input [4:0] id_RegB,
    input [4:0] id_RegWr,
    input [87:0] id_control, // opb, shamt, nextad, link, regDest, jm, br, memrd, memwrt, has_imm, rgwrt, jreg, szextend, sys, alucon[5:0], hilo[1:0]

    //from FRAT
    input [5:0] frat_my_map [31:0],

    //from RRAT
    input rrat_free,
    input [5:0] rrat_free_reg,
    input [5:0] rrat_map [31:0],

    //halt signals
    input issue_halt,
    input lsq_halt,
    input rob_halt,

    //from EXE
    input exe_busyclear_flag,
    input [5:0] exe_busyclear_reg,

    //to FRAT
    output reg [4:0] reg_to_map_FRAT,
    output reg [5:0] new_mapping,
    output reg remap_FRAT,

    //to issue queue
    output reg entry_allocate_issue,
    output reg [169:0] entry_issue, //Instr [88:57], instr_pc [56:25], control[24:18], MAPC[17:12], MAPB[11:6], MAPA[5:0]
    output reg [63:0] busy,

    //to LSQ
    output reg entry_ld_lsq,
    output reg entry_st_lsq,
    output reg [169:0] entry_lsq,

    //to ROB
    output reg entry_allocate_ROB,
    output reg [169:0] entry_ROB,

    //
    output reg [4:0] oldA,
    output reg [4:0] oldB,
    output reg [4:0] oldC,
    // stalling the rename queue
    output halt_rename_queue,

    output integer instr_num);

reg  [5:0] free_reg;
wire id_ld_flag;
wire id_st_flag;
wire id_RegWr_flag;
wire free_halt;

assign id_ld_flag = id_control[14];
assign id_st_flag = id_control[13];
assign id_RegWr_flag = id_control[11] & (id_instr != 0);

assign halt_rename_queue = issue_halt | STALL | rob_halt | lsq_halt | free_halt;

QUEUE_obj #(.INIT(1), .LENGTH(32), .WIDTH(6)) freelist (
      .clk(CLK),
      .reset(RESET),
      .stall(STALL),
      .flush(FLUSH),

      .enque(rrat_free),
      .enque_data(rrat_free_reg),

      .deque(id_RegWr_flag | id_ld_flag),
      .deque_data(free_reg),

      .r_mapping(rrat_map),
      .halt(free_halt));


always @(negedge CLK or negedge RESET) begin
    if(!RESET) begin
        entry_allocate_ROB <= 0;
        entry_allocate_issue <= 0;
        entry_ld_lsq <= 0;
        entry_st_lsq <= 0;
        busy <= 0;
        instr_num <= 0;
        remap_FRAT <= 0;
        oldA <= 0;
        oldB <= 0;
        oldC <= 0;
    end else if(!CLK & !(issue_halt | STALL | rob_halt | lsq_halt | free_halt | FLUSH)) begin
        entry_allocate_ROB <= 1;
        instr_num <= instr_num + 1;
        entry_ROB[169:18] <= {id_control, id_instr, id_instrpc};
        entry_ROB[11:0]  <= {frat_my_map[id_RegB], frat_my_map[id_RegA]};
        entry_ROB[17:12] <= id_RegWr_flag ? free_reg : frat_my_map[id_RegWr];

        entry_allocate_issue <= ~(id_ld_flag | id_st_flag);
        entry_issue[169:18] <= {id_control, id_instr, id_instrpc};
        entry_issue[11:0]  <= {frat_my_map[id_RegB], frat_my_map[id_RegA]};
        entry_issue[17:12] <= id_RegWr_flag ? free_reg : frat_my_map[id_RegWr];

        remap_FRAT <= id_RegWr_flag | id_ld_flag;
        new_mapping <= free_reg;
        reg_to_map_FRAT <= id_RegWr;

        entry_ld_lsq <= id_ld_flag;
        entry_st_lsq <= id_st_flag;
        entry_lsq[169:18] <= {id_control, id_instr, id_instrpc};
        entry_lsq[11:0]  <= {frat_my_map[id_RegB], frat_my_map[id_RegA]};
        entry_lsq[17:12] <= (id_ld_flag) ? free_reg : frat_my_map[id_RegWr];

        busy[frat_my_map[id_RegWr]] <= (id_RegWr_flag | id_ld_flag) ? 1 : busy[frat_my_map[id_RegWr]];
        busy[exe_busyclear_reg] <= exe_busyclear_flag ? 0 : busy[exe_busyclear_reg];

        oldA <= id_RegA;
        oldB <= id_RegB;
        oldC <= id_RegWr;
    end else begin
        entry_allocate_ROB <= 0;
        entry_allocate_issue <= 0;
        entry_ld_lsq <= 0;
        entry_st_lsq <= 0;
        entry_ROB <= 0;
        remap_FRAT <= 0;
        oldA <= 0;
        oldB <= 0;
        oldC <= 0;
        if(FLUSH) begin
            busy <= 0;
        end
        else begin
            busy[exe_busyclear_reg] <= exe_busyclear_flag ? 0 : busy[exe_busyclear_reg];
        end
    end
end

always @(negedge CLK) begin
    `ifdef RENAME
    $display("Rename");
    $display("Instr: %x, InstrPC: %x", id_instr, id_instrpc);
    $display("RS: %d, RT: %d, RD: %d, MS: %d, MT: %d, MD: %d", id_RegA, id_RegB, id_RegWr, frat_my_map[id_RegA], frat_my_map[id_RegB], (id_ld_flag) ? free_reg : frat_my_map[id_RegWr]);
    $display("Reg Wrt?: %x, Load?: %x", id_RegWr_flag, id_ld_flag);
    $display("Reg to Map: %d, New Mapping: %d, Remap?: %x", id_RegWr, free_reg, id_RegWr_flag | id_ld_flag);
    $display("Busy clear: %x, Busy clear reg: %d", exe_busyclear_flag, exe_busyclear_reg);
    $display("End Rename");
    `endif
end

endmodule
