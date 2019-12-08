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
    input [6:0] id_control, 

    //from FRAT
    input [5:0] frat_my_map [31:0],

    //from RRAT
    input rrat_free,
    input [5:0] rrat_free_reg, 

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
    output reg [88:0] entry_issue, //Instr [88:57], instr_pc [56:25], control[24:18], MAPC[17:12], MAPB[11:6], MAPA[5:0] 
    output reg [63:0] busy,

    //to LSQ
    output reg entry_ld_lsq,
    output reg entry_st_lsq,
    output reg [88:0] entry_lsq,

    //to ROB
    output reg entry_allocate_ROB,
    output reg [88:0] entry_ROB,

    output integer instr_num
);

wire free_halt;
reg  [5:0] free_reg;
wire id_ld_flag;
wire id_st_flag;
wire id_RegWr_flag;


assign id_ld_flag = id_control[4];
assign id_st_flag = id_control[3];
assign id_RegWr_flag = id_control[5];

QUEUE_obj #(.LENGTH(32), .WIDTH(6)) freelist (
      .clk(CLK),
      .reset(RESET),
      .stall(STALL),
      .flush(FLUSH),

      .enque(rob_free),
      .enque_data(rob_free_reg),

      .deque(id_RegWr_flag | id_ld_flag),
      .deque_data(free_reg),
      .halt(free_halt)
      );


always @(negedge CLK or negedge RESET) begin
    if(!RESET) begin
        entry_allocate_ROB <= 0;
        entry_allocate_issue <= 0;
        entry_ld_lsq <= 0;
        entry_st_lsq <= 0;
        busy <= 0;
        instr_num <= 0;
        remap_FRAT <= 0;
        $display("");
    end else if(!CLK & !(free_halt | issue_halt | STALL | rob_halt | lsq_halt |  (free_reg == 0) ) ) begin
        entry_allocate_ROB <= 1;
        instr_num <= instr_num + 1;
        entry_ROB[88:18] <= {id_instr, id_instrpc, id_control};
        entry_ROB[11:0]  <= {frat_my_map[id_RegB], frat_my_map[id_RegA]};
        entry_ROB[17:12] <= id_RegWr_flag ? free_reg : frat_my_map[id_RegWr];
        
        entry_allocate_issue <= ~(id_ld_flag | id_st_flag);
        entry_issue[88:18] <= {id_instr, id_instrpc, id_control};
        entry_issue[11:0]  <= {frat_my_map[id_RegB], frat_my_map[id_RegA]};
        entry_issue[17:12] <= id_RegWr_flag ? free_reg : frat_my_map[id_RegWr];
        
        remap_FRAT <= id_RegWr_flag | id_ld_flag; 
        new_mapping <= free_reg; 
        reg_to_map_FRAT <= id_RegWr;

        entry_ld_lsq <= id_ld_flag;
        entry_st_lsq <= id_st_flag;
        entry_lsq <= entry_issue[88:18] <= {id_instr, id_instrpc, id_control};
        entry_issue[11:0]  <= {frat_my_map[id_RegB], frat_my_map[id_RegA]};
        entry_issue[17:12] <= (id_ld_flag) ? free_reg : frat_my_map[id_RegWr];

        busy[frat_my_map[id_RegWr]] <= (id_RegWr_flag | id_ld_flag ) ? 1 : busy[frat_my_map[id_RegWr]];
        busy[exe_busyclear_reg] <= exe_busyclear_flag ? 0 : busy[exe_busyclear_reg];
    end else begin
        entry_allocate_ROB <= 0;
        entry_allocate_issue <= 0;
        entry_ld_lsq <= 0;
        entry_st_lsq <= 0;
        remap_FRAT <= 0;
    end
end

endmodule