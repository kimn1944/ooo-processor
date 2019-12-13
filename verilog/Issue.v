module Issue (
    input CLK,
    input RESET,
    input STALL,
    input FLUSH,  

    //from rename
    input rename_enque,
    input integer rename_instr_num;
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

    output reg [4:0]    shamt_exe,
    output reg [5:0]    ALU_con_exe,
    output reg          RegWr_exe,
    output reg          MemWr_exe,    
    output reg          MemRd_exe,
    output reg          branch_exe,
    output reg          jump_exe,
    output reg          jumpReg_exe,
    output reg          regDest_exe,
    output reg          link_exe,
    output reg [1:0]    hilo_exe,
    output reg          sys_exe,
    output reg          ALUSrc_exe,

    output reg [31:0]   alt_PC_exe,
    output reg [31:0]   operandA1_exe,
    output reg [31:0]   operandB1_exe,
    output reg [31:0]   MemWriteData_exe,

    //from ROB
    input integer rob_instr_num,

    // //to ROB for branch misprediction
    // output miss_flag_rob,
    // output miss_instr_num_rob,

    // output request_alt_pc_rob,
    // output alt_pc_rob,

    //halt signal
    output reg issue_halt
    //do branch in execution
);
reg [136:0] issue_q [15:0];
reg [31:0] Operand_q [2:0][15:0];
reg [15:0] ready_q [2:0];
reg [15:0] empty_in_issue;

wire [5:0] MapA     =  rename_issueinfo[5:0];
wire [5:0] MapB     =  rename_issueinfo[11:6];

wire [5:0] MapWr    =  rename_issueinfo[17:12];
wire [31:0] Instr   = rename_issueinfo[49:18];
wire [31:0] Instr_pc = rename_issueinfo[81:50];
wire [4:0] shamt    = rename_issueinfo[86:82];
wire [5:0] alu_con  = rename_issueinfo[92:87];
wire RegWr_flag     = rename_issueinfo[93];
wire MemWr_flag     = rename_issueinfo[94];
wire MemRd_flag     = rename_issueinfo[95];
wire branch_flag    = rename_issueinfo[96];
wire jump_flag      = rename_issueinfo[97];
wire jr_flag        = rename_issueinfo[98];

wire RegDest_flag   = rename_issueinfo[99];
wire link_flag      = rename_issueinfo[100];
wire [1:0] hilo     = rename_issueinfo[102:101];
wire sys_flag       = rename_issueinfo[103];
wire ALUSrc_flag    = rename_issueinfo[104];

wire [31:0] Alt_PC    = rename_issueinfo[136:105]; //sent jump/branch immediates
wire [31:0] OpB1      = rename_issueinfo[168:137]; //sent immediates

//reg  [31:0]MemWriteData;

integer instr_out_index;
integer empty_spot;
integer i, j, k, l, m, n;
integer instr_num [16:0];
//assign ready_q[0][0] = (broadcast_reg == ) or ready_que and instr_in; //add implementation for when instruction leave  

wire [15:0] instr_ready = ready_q[0] & ready_q[1] & ready_q[2];
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
    i = 0;
    j = 0;
    k = 0;
    l = 0;
    m = 0;
    n = 0;
    ready_q[0] = 0;
    ready_q[1] = 0;
    ready_q[2] = 0;
    for (i = 0; i < 16; i = i+1)begin
        Operand_q[0][i] = 0;
        Operand_q[1][i] = 0;
        Operand_q[2][i] = 0;
    end
end


//updating ready queue and operand queue
always @(posedge CLK or negedge RESET) begin
    if (!RESET or FLUSH) begin
        empty_in_issue <= 0;
        i = 0;
        ready_q[0] = 0;
        ready_q[1] = 0;
        ready_q[2] = 0;
        for (i = 0; i < 16; i = i+1)begin
            Operand_q[0][i] = 0;
            Operand_q[1][i] = 0;
            Operand_q[2][i] = 0;
        end
    end else if (CLK and !STALL ) begin
        if (rename_enque and (empty_spot < 16)) begin
            empty_in_issue[empty_spot]   <= 0;
            issue_q[empty_spot][136:0]               <= rename_issueinfo[136:0];
            ready_q[0][empty_spot] <= (MapA == 0) ? 1 : busy[MapA];//(jump_flag & jr_flag) ? 1 : (link_flag ? 0 :1);
            ready_q[1][empty_spot] <= (MapB == 0) ? 1 : busy[MapB];
            ready_q[2][empty_spot] <= (RegDest_flag || link_flag || !MapWr) ? 1 : busy[MapWr]; //This is for Memwrite

            Operand_q[0][empty_spot] <= (MapA == 0) ? OpA1 : 0;
            Operand_q[1][empty_spot] <= (MapB == 0) ? OpB1 : 0;
            Operand_q[2][empty_spot] <= 0;
            //WriteRegister1 = RegDst1?rd1:(link1?5'd31:rt1);
        end

        if (instr_out_index != 16) begin
            RegWr_exe       <= issue_q[instr_out_index][17:12];
            instr_exe       <= issue_q[instr_out_index][49:18];
            instru_pc_exe   <= issue_q[instr_out_index][81:50];
            shamt_exe       <= issue_q[instr_out_index][86:82];
            ALU_con_exe     <= issue_q[instr_out_index][92:87];
            RegWr_exe       <= issue_q[instr_out_index][93];
            MemWr_exe       <= issue_q[instr_out_index][94];    
            MemRd_exe       <= issue_q[instr_out_index][95];
            branch_exe      <= issue_q[instr_out_index][96];
            jump_exe        <= issue_q[instr_out_index][97];
            jumpReg_exe     <= issue_q[instr_out_index][98];
            
            regDest_exe     <= issue_q[instr_out_index][99];
            link_exe        <= issue_q[instr_out_index][100];
            hilo_exe        <= issue_q[instr_out_index][102:101];
            sys_exe         <= issue_q[instr_out_index][103];
            ALUSrc_flag     <= issue_q[instr_out_index][104];
            alt_PC_exe      <= issue_q[instr_out_index][136:105];

            operandA1_exe   <= Operand_q[0][instr_out_index];
            operandB1_exe   <= Operand_q[1][instr_out_index];
            MemWriteData_exe<= Operand_q[2][instr_out_index];
            empty_in_issue[instr_out_index] <= 1;
            issue_q[instr_out_index]        <= 0;
            Operand_q[0][instr_out_index]   <= 0;
            Operand_q[1][instr_out_index]   <= 0;
            Operand_q[2][instr_out_index]   <= 0;
        end else begin
            RegWr_exe       <= 0;
            instr_exe       <= 0;
            instru_pc_exe   <= 0;
            shamt_exe       <= 0;
            ALU_con_exe     <= 0;
            RegWr_exe       <= 0;
            MemWr_exe       <= 0; 
            MemRd_exe       <= 0;
            branch_exe      <= 0;
            jump_exe        <= 0;
            jumpReg_exe     <= 0;
            
            regDest_exe     <= 0;
            link_exe        <= 0;
            hilo_exe        <= 0;
            sys_exe         <= 0;
            ALUSrc_flag     <= 0;
            alt_PC_exe      <= 0;

            operandA1_exe   <= 0;
            operandB1_exe   <= 0;
            MemWriteData_exe<= 0;

        end
    end
end

always @(negedge CLK or negedge RESET) begin
    if (!RESET or FLUSH) begin

    end else if (!CLK and !STALL ) begin
        //matching exe broadcast reg with current reg
        if (exe_broadcast) begin
            for (i = 0; i < 16; i = i+1)begin
                if (empty_in_issue[i] != 1) begin
                    Operand_q[0][i] <= ((issue_q[i][5:0] == exe_broadcast_map) && (issue_q[i][5:0] != 0)) ? exe_broadcast_val : Operand_q[0][i];
                    Operand_q[1][i] <= ((issue_q[i][11:6] == exe_broadcast_map) && (issue_q[i][11:6] != 0)) ? exe_broadcast_val : Operand_q[1][i];
                    Operand_q[2][i] <= ((issue_q[i][17:12] == exe_broadcast_map) && (issue_q[i][17:12] != 0)) ? exe_broadcast_val : Operand_q[2][i];
                    ready_q[0][i] <= (issue_q[i][5:0] == exe_broadcast_map) ? 1 : ready_q[0][i];
                    ready_q[1][i] <= (issue_q[i][11:6] == exe_broadcast_map) ? 1 : ready_q[1][i];
                    ready_q[2][i] <= (issue_q[i][17:12] == exe_broadcast_map) ? 1 : ready_q[2][i];
                end else begin
                //we actually don't need this since we can check if item is not valid in issue queue with the empty_in_issue array, but just in case. 
                    Operand_q[0][i] <= 0;
                    Operand_q[1][i] <= 0;
                    Operand_q[2][i] <= 0;         
                    ready_q[0][i] <= 0;
                    ready_q[1][i] <= 0;
                    ready_q[2][i] <= 0;
                end
            end
        end


    end
end


endmodule