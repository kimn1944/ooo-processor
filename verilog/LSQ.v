`include "config.v"

module LSQ (
    input CLK,
    input RESET,
    input STALL,
    input FLUSH,

    //from rename
    input integer rename_instr_num,
    input [169:0] rename_entry_lsq,

    //from EXE
    input           exe_MemRd_flag,
    input           exe_MemWr_flag,
    input [31:0]    exe_ALU_result, //this contains mem rd/wr access address information
    input [31:0]    exe_MemWr_data,
    input integer   exe_instr_num,

    //from MEM
    input           mem_miss_halt, //missed in the cache, don't have parallelism

    //from rob
    input integer   rob_instr_head_num,

    //to MEM
    output [31:0]   instr_mem,
    output [31:0]   instr_pc_mem,
    output [31:0]   ALU_result_mem, //the resolved memory address to access
    output [5:0]    RegWr_map_mem,
    output [31:0]   MemWrData_mem,
    output          RegWr_flag_mem,
    output [5:0]    ALU_Control_mem,
    output          MemRd_flag_mem,
    output          MemWr_flag_mem,
    output integer  instr_num_mem,


    // stalling the rename queue
    output          halt_rename_queue);


    wire [5:0]  MapWr       = rename_entry_lsq[17:12];
    wire [31:0] instr       = rename_entry_lsq[81:50];
    wire [31:0] instr_pc    = rename_entry_lsq[49:18];
    wire [5:0]  alu_control = rename_entry_lsq[89:84];

    wire RegWr_flag         = rename_entry_lsq[93];
    wire memWr_flag         = rename_entry_lsq[95];
    wire memRd_flag         = rename_entry_lsq[96];

    integer i;
    wire rename_enque;
    reg [3:0]tail_pointer;
    reg [3:0]head_pointer;
    integer queue_size;
    //integer instr_num_dly;

    reg [31:0] LSQ_data [15:0][3:0]; //[0]instr, [1]instr_pc, [2]alu_result, [3]MemWr_data
    reg [5:0]  LSQ_ALU  [15:0][1:0]; //[0]MapWr, [1]alu_control
    reg [2:0]  LSQ_flags[15:0];      //[0]0 if is a load, 1 if is a store, [1]RegWr_flag, [2]EA resolved
    integer    instr_num[15:0];

    assign halt_rename_queue = queue_size == 16;
    assign rename_enque      = memRd_flag || memWr_flag;

//non speculative implementation, without forwarding for now
always @(posedge CLK or negedge RESET)begin
    if (!RESET || FLUSH) begin
        head_pointer <= 0;
        tail_pointer <= 0;
        queue_size   <= 0;
        for (i = 0; i < 16; i++) begin
            instr_num  [i] = 0;
            LSQ_data[i][0] = 0;
            LSQ_data[i][1] = 0;
            LSQ_data[i][2] = 0;
            LSQ_data[i][3] = 0;

            LSQ_ALU [i][0] = 0;
            LSQ_ALU [i][1] = 0;
            LSQ_flags  [i] = 0;
        end
    end else if (CLK) begin
        if(rename_enque && (queue_size < 16)) begin
            instr_num[tail_pointer]    <= rename_instr_num;
            LSQ_data[tail_pointer][0]  <= instr;
            LSQ_data[tail_pointer][1]  <= instr_pc;

            LSQ_ALU [tail_pointer][0]  <= MapWr;
            LSQ_ALU [tail_pointer][1]  <= alu_control;

            LSQ_flags[tail_pointer][0] <= memWr_flag;
            LSQ_flags[tail_pointer][1] <= RegWr_flag;
            LSQ_flags[tail_pointer][2] <= 0;

            tail_pointer    <= tail_pointer +1;
        end
        queue_size          <= queue_size + (rename_enque && (queue_size < 16));//(rename_enque & (tail_pointer +1 != head_pointer)) ? ((!mem_miss_halt & LSQ_flags[head_pointer][2] ) ? queue_size : queue_size +1) : ((!mem_miss_halt & LSQ_flags[head_pointer][2] ) ? queue_size -1 : queue_size);

        if (LSQ_flags[head_pointer][2] && (!LSQ_flags[head_pointer][0] || (rob_instr_head_num == instr_num[head_pointer]))) begin
            instr_mem       <= LSQ_data[head_pointer][0];
            instr_pc_mem    <= LSQ_data[head_pointer][1];
            ALU_result_mem  <= LSQ_data[head_pointer][2];
            RegWr_map_mem   <= LSQ_ALU[head_pointer][0];
            MemWrData_mem   <= LSQ_data[head_pointer][3];
            RegWr_flag_mem  <= LSQ_flags[head_pointer][1];
            ALU_Control_mem <= LSQ_ALU[head_pointer][1];
            MemRd_flag_mem  <= ~LSQ_flags[head_pointer][0];
            MemWr_flag_mem  <= LSQ_flags[head_pointer][0];
            instr_num_mem   <= instr_num[head_pointer];
            //instr_num_dly   <= instr_num[head_pointer]; //not sure if neccessary for any applications
        end else begin
            instr_mem       <= 0;
            instr_pc_mem    <= 0;
            ALU_result_mem  <= 0;
            RegWr_map_mem   <= 0;
            MemWrData_mem   <= 0;
            RegWr_flag_mem  <= 0;
            ALU_Control_mem <= 0;
            MemRd_flag_mem  <= 0;
            MemWr_flag_mem  <= 0;
            instr_num_mem   <= 0;
        end
    end
end

always @(negedge CLK)begin
    if (RESET && !CLK) begin
        if(exe_MemRd_flag || exe_MemWr_flag) begin
            for (i = 0; i < 16; i = i + 1) begin
                if ((exe_instr_num == instr_num[i]) && (instr_num[i] != 0)) begin
                    LSQ_data[i][2]     = exe_ALU_result;
                    LSQ_data[i][3]     = exe_MemWr_data;
                    LSQ_flags[i][2]    = 1; //for forwarding purpose, check if load and check older store's EA
                end
            end
        end

        if (!mem_miss_halt && LSQ_flags[head_pointer][2] && (!LSQ_flags[head_pointer][0] || (rob_instr_head_num == instr_num[head_pointer]))) begin
            instr_num[head_pointer] <= 0;
            LSQ_data[head_pointer][0] <= 0;
            LSQ_data[head_pointer][1] <= 0;
            LSQ_data[head_pointer][2] <= 0;
            LSQ_data[head_pointer][3] <= 0;

            LSQ_ALU [head_pointer][0] <= 0;
            LSQ_ALU [head_pointer][1] <= 0;
            LSQ_flags  [head_pointer] <= 0;

            head_pointer              <= head_pointer + 1;
            queue_size                <= queue_size - 1;
        end

    end
end

endmodule
