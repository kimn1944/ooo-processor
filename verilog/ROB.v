/*
* File: ROB.v
* Author: Nikita Kim & Celine Wang
* Email: kimn1944@gmail.com
* Date: 12/7/19
*/

`include "config.v"

module ROB
    #()
    (input clk,
    input reset,
    input stall,
    //input flush, //do we need this?

    //from rename
    input rename_enque,
    input integer rename_instr_num,
    input [4:0] rename_RegWr,
    input [169:0] rename_enque_data,

    //from exe
    input exe_complete_flag,
    input exe_broadcast_flag, //might not need, for debugging purpose
    input exe_Request_alt_pc, //sent at misprediction
    input [31:0]  exe_Alt_PC,
    input integer exe_instr_num,

    //from mem
    input mem_complete_flag,
    input mem_broadcast_flag, //might not need, for debugging purpose
    input integer mem_instr_num,

    //from RRAT
    input [5:0] rrat_map [31:0], //might not need, for debugging purpose

    //to IF
    output reg Request_alt_pc_IF, //if previous previous is a mispredict or previous is a syscall
    output reg [31:0] Alt_PC_IF, //PC+4 for syscall, Alt_PC for mispred

    //to Issue and lsq (to signal hilo and store to commit)
    output integer head_instr_num,

    //to rename
    output reg ROB_halt,
    output reg rename_free, //rrat does this I did not implement here
    output reg [5:0] rename_free_reg, //rrat does this I did not implement here

    //to rrat
    output reg newMap_flag_rrat,
    output reg [4:0]reg2map_rrat,
    output reg [5:0]newMap_rrat,

    //to MIPS
    output reg SYS, //should we also use this bit to stall the IF for one cycle? (I don't think so because we have the
    // alt pc ready and sys does not mess with instruction cache yay, but maybe we do need to set all of IF's current
    // output to ID to 0 if it receive flush signal)
    output reg flush);


    integer i;
    reg [5:0]   commit_pointer;
    reg [5:0]   enque_pointer;
    integer     queue_size;

    reg [2:0]   ready2commit_q[63:0]; //[0]jump or branch, [1]sys, [2]completion bit
    reg [11:0]  remap_info_q  [63:0]; //[11]RegWr flag, [10:5]MapWr, [4:0]RegWr
    reg [32:0]  mispre_q      [63:0]; //[32]mispred or syscall, [31:0]ALT PC or syscall pc+4
    integer     instr_num_q   [63:0];

    assign      ROB_halt          = (64 == queue_size);
    assign      head_instr_num    = instr_num_q[commit_pointer];

    //for misprediction recovery
    reg [31:0] Alt_PC_dly;
    reg        Req_alt_PC_dly;
    reg        flush_dly;

    wire [11:0] rename_remap_info   = {rename_enque_data[93], rename_enque_data[17:12], rename_RegWr}; //RegWr_flag, MapWr, RegWr
    wire  [2:0] rename_ready2commit = {1'b0, rename_enque_data[90], {rename_enque_data[97] || rename_enque_data[98]}}; //[2]completion bit, [1]sys, [0]jump or branch
    wire        rename_Req_alt      = rename_enque_data[90] || rename_enque_data[98]; //sys or jump
    wire [31:0] rename_ini_alt_pc   = rename_enque_data[49:18] + 4; //pc+4, for syscall


    //if hilo, issue at rob head. If store, access memory at rob head, If jump, branch, sys, commit at ROB head

//non speculative implementation
always @(posedge clk or negedge reset)begin
    if (!reset) begin
        enque_pointer   <= 0;
        commit_pointer  <= 0;
        queue_size      <= 0;
        Alt_PC_dly      <= 0; //check if rob
        Req_alt_PC_dly  <= 0;
        flush_dly       <= 0;
        for (i = 0; i < 64; i++) begin
            remap_info_q[i]    = 0;
            ready2commit_q[i]  = 0;
            mispre_q[i]        = 0;
            instr_num_q[i]     = 0;
        end
    end else if (clk) begin
        if(rename_enque && (queue_size < 64)) begin
            ready2commit_q[enque_pointer]   <= rename_ready2commit;
            instr_num_q[enque_pointer]      <= rename_instr_num;
            remap_info_q[enque_pointer]     <= rename_remap_info;
            mispre_q[enque_pointer][31:0]   <= rename_ini_alt_pc;
            mispre_q[enque_pointer][32]     <= rename_Req_alt;
            enque_pointer                   <= enque_pointer + 1;
            //queue_size                      <= queue_size +1;
        end
        queue_size <= (rename_enque && (queue_size < 64)) ? ((ready2commit_q[commit_pointer][2]) ? queue_size : queue_size +1) : ((ready2commit_q[commit_pointer][2]) ? queue_size - 1 : queue_size);

        if(ready2commit_q[commit_pointer][2]) begin
            Request_alt_pc_IF<= Req_alt_PC_dly ? Req_alt_PC_dly : (ready2commit_q[commit_pointer][0] ? 0 : mispre_q[commit_pointer][32]);
            Alt_PC_IF        <= Req_alt_PC_dly ? Alt_PC_dly : (ready2commit_q[commit_pointer][0] ? 0 : mispre_q[commit_pointer][31:0]);

            newMap_flag_rrat <= remap_info_q[commit_pointer][11];
            newMap_rrat      <= remap_info_q[commit_pointer][10:5];
            reg2map_rrat     <= remap_info_q[commit_pointer][4:0];

            SYS              <= ready2commit_q[commit_pointer][1];
            flush            <= flush_dly ? flush_dly : (ready2commit_q[commit_pointer][0] ? 0 : mispre_q[commit_pointer][32]);

            Alt_PC_dly       <= mispre_q[commit_pointer][31:0]; //check if rob
            Req_alt_PC_dly   <= ready2commit_q[commit_pointer][0] ? mispre_q[commit_pointer][32] : 0;
            flush_dly        <= ready2commit_q[commit_pointer][0] ? mispre_q[commit_pointer][32] : 0;

            remap_info_q  [commit_pointer]    <= 0;
            ready2commit_q[commit_pointer]    <= 0;
            mispre_q      [commit_pointer]    <= 0;
            instr_num_q   [commit_pointer]    <= 0;
            commit_pointer                    <= commit_pointer + 1;
            //queue_size                        <= queue_size -1;
            if (flush_dly ? flush_dly : (ready2commit_q[commit_pointer][0] ? 0 : mispre_q[commit_pointer][32])) begin
                enque_pointer   <= 0;
                commit_pointer  <= 0;
                queue_size      <= 0;
                Alt_PC_dly      <= 0; //check if rob
                Req_alt_PC_dly  <= 0;
                flush_dly       <= 0;
                flush           <= 0;
                Alt_PC_IF       <= 0;
                Request_alt_pc_IF <= 0;
                for (i = 0; i < 64; i = i + 1) begin
                    remap_info_q[i]    = 0;
                    ready2commit_q[i]  = 0;
                    mispre_q[i]        = 0;
                    instr_num_q[i]     = 0;
                end
            end
        end
    end
end


always @(negedge clk) begin
    if (reset & !clk & !flush) begin
        if (exe_complete_flag | mem_complete_flag) begin
            for(i = 0; i < 64; i = i + 1) begin
                ready2commit_q[i][2] = ((exe_complete_flag & (exe_instr_num == instr_num_q[i])) | (mem_complete_flag & (mem_instr_num == instr_num_q[i]))) ? 1'b1 : ready2commit_q[i][2];

                if (exe_complete_flag & (exe_instr_num == instr_num_q[i]) & (instr_num_q[i] != 0)) begin
                    mispre_q[i][31:0] <= (ready2commit_q[i][0] & ~ready2commit_q[i][1]) ? exe_Alt_PC : mispre_q[i][31:0]; //jorb and not sys
                    mispre_q[i][32]   <= (ready2commit_q[i][0] & ~ready2commit_q[i][1]) ? exe_Request_alt_pc : mispre_q[i][32]; //jorb and not sys
                end
            end
        end
    end
end


endmodule
