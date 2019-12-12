module Issue (
    input CLK,
    input RESET,
    input STALL,
    input FLUSH,  

    //from rename
    input rename_enque,
    input interger rename_instr_num;
    input [185:0] rename_issueinfo,
    input [63:0] busy,

    //from execution
    input exe_broadcast;
    input [5:0] exe_broadcast_map,
    input [31:0] exe_broadcast_val,

    //to execution

    output reg [5:0]    RegWr_exe,    
    output reg [31:0]   instr_exe,
    output reg [31:0]   instru_pc_exe,

    output reg [31:0]   operandA1_exe,
    output reg [31:0]   operandB1_exe,
    output reg [4:0]    shamt_exe,
    output reg [5:0]    ALU_con_exe,
    output reg          RegWr_exe,
    output reg          MemWr_exe,    
    output reg          MemRd_exe,
    output reg          branch_exe,
    output reg          jump_exe,
    output reg          jumpReg_exe,
    output reg [31:0]   MemWriteData_exe,



    
    //ROB
    input integer rob_instr_num;

    //halt signal
    output reg issue_halt
    //do branch in execution
);
reg [193:0] issue_q [15:0];
reg [15:0] ready_q [1:0];
reg [15:0] empty_in_issue;

wire [5:0] MapA     =  rename_issueinfo[5:0];
wire [5:0] MapB     =  rename_issueinfo[11:6];

wire [5:0] MapWr    =  rename_issueinfo[17:12];
wire [31:0] Instr   = rename_issueinfo[49:18];
wire [31:0] Instr_pc = rename_issueinfo[81:50];
reg  [31:0] OpA1;
wire [31:0] OpB1    = rename_issueinfo[113:82];
wire [4:0] shamt    = rename_issueinfo[118:114];
wire [5:0] alu_con  = rename_issueinfo[124:119];
wire RegWr_flag     = rename_issueinfo[125];
wire MemWr_flag     = rename_issueinfo[126];
wire MemRd_flag     = rename_issueinfo[127];
wire branch_flag    = rename_issueinfo[128];
wire jump_flag      = rename_issueinfo[129];
reg  [31:0]MemWriteData;

wire RegDest_flag   = rename_issueinfo[130];
wire link_flag      = rename_issueinfo[131];
wire [1:0] hilo     = rename_issueinfo[133:132];
wire sys_flag       = rename_issueinfo[134];
wire jr_flag        = rename_issueinfo[135];
wire ALUSrc_flag    = rename_issueinfo[136];

integer instr_out_index;
integer empty_spot;
integer i, j, k, l, m, n;
//assign ready_q[0][0] = (broadcast_reg == ) or ready_que and instr_in; //add implementation for when instruction leave  

wire [15:0] instr_ready = ready_q[0] & ready_q[1];
wire [15:0] instr_grant;
assign issue_halt = (empty_spot == 16) or (empty_in_issue == 0); 

Arbiter_main instr_Arbiter(
    .ready(instr_ready),
    .grant(instr_grant),
    .granted(instr_out_index)
);

Arbiter_main issue_Arbiter(
    .ready(empty_in_issue),
    .grant(),
    .granted(empty_spot)
);

initial begin
    empty_in_issue = 16'b1111111111111111;
end

//matching exe broadcast reg with current reg
    input exe_broadcast;
    input [5:0] exe_broadcast_map,
    input [31:0] exe_broadcast_val,
always @(exe_broadcast or FLUSH or enque) begin
    if (FLUSH) begin
        i = 0;
        ready_q[0] = 0;
        ready_q[1] = 0;
        // for (i = 0; i < 16; i = i+1)begin
        //     issue_q[i] = 0;
        // end
    end else if (!STALL and enque)begin
        ready_q[0][empty_spot] = (MapA == 0) ? 1 : busy[MapA];//(jump_flag & jr_flag) ? 1 : (link_flag ? 0 :1);
        ready_q[1][empty_spot] = (MapB == 0) ? 1 : busy[MapB];
    end else if (!STALL and exe_broadcast) begin
        for (i = 0; i < 16; i = i+1)begin
            ready_q[0][i] = (issue_q[i][5:0] == exe_broadcast_map) ? 1 : ready_q[0][i];
            ready_q[1][i] = (issue_q[i][11:6] == exe_broadcast_map) ? 1 : ready_q[1][i];
        end
    end

end

always @(posedge CLK or negedge RESET) begin
    if (!RESET) begin

    end else if (CLK and !STALL and enque) begin


    end

end


endmodule