`include "config.v"
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    12:09:45 10/18/2013
// Design Name:
// Module Name:    EXE2
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module EXE(
//***************************//***************************//********************
    input [169:0] IF_all_info,
    output reg Request_Alt_PC,
    output reg [31:0] alt_addr,
    output flush,
    output [169:0] all_info_MEM,

    // input [5:0] issue_RegWr_map,
    // input issue_RegWr_flag,
    // //from issue q
    // input issue_branch_flag,
    // input issue_jump_flag,
    // input issue_jr_flag,
    // input issue_regDest_flag,
    // input issue_link_flag,
    // input issue_hilo_flag,
    // input issue_sys_flag,
    // input issue_ALUSrc_flag,
    // input [31:0] issue_alt_PC,
    // input integer issue_instr_num,

    //
    // //broadcast (to issue queue, phys reg, and lsq)
    // output reg broadcast_flag,
    // output reg [5:0] broadcast_Map,
    // output reg [31:0] broadcast_val,
    // //the RegWrite1_out under this is the signal to write
    //
    // //to Mem stage and rob
    // output integer exe_instr_num,
    // output reg complete_flag_rob,
    // output reg RegWr_flag_lsq,
//***************************//***************************//********************
    input CLK,
    input RESET,
	 //Current instruction [debug]
    input [31:0] Instr1_IN,
    //Current instruction's PC [debug]
    input [31:0] Instr1_PC_IN,
    //Operand A (if already known)
    input [31:0] OperandA1_IN,
    //Operand B (if already known)
    input [31:0] OperandB1_IN,
    //Destination register
    input [4:0] WriteRegister1_IN,
    //Data in MemWrite1 register
    input [31:0] MemWriteData1_IN,
    //We do a register write
    input RegWrite1_IN,
    //ALU Control signal
    input [5:0] ALU_Control1_IN,
    //We read from memory (passed to MEM)
    input MemRead1_IN,
    //We write to memory (passed to MEM)
    input MemWrite1_IN,
    //Shift amount (needed for shift operations)
    input [4:0] ShiftAmount1_IN,
    //Instruction [debug] to MEM
    output reg [31:0] Instr1_OUT,
    //PC [debug] to MEM
    output reg [31:0] Instr1_PC_OUT,
    //Our ALU results to MEM
    output reg [31:0] ALU_result1_OUT,
    //What register gets the data (or store from) to MEM
    output reg [4:0] WriteRegister1_OUT,
    //Data in WriteRegister1 (if known) to MEM
    output reg [31:0] MemWriteData1_OUT,
    //Whether we will write to a register
    output reg RegWrite1_OUT,
    //ALU Control (actually used by MEM)
    output reg [5:0] ALU_Control1_OUT,
    //We need to read from MEM (passed to MEM)
    output reg MemRead1_OUT,
    //We need to write to MEM (passed to MEM)
    output reg MemWrite1_OUT
    );


wire [31:0] A1;
wire [31:0] B1;
wire [31:0] ALU_result1;

wire comment1;
assign comment1 = 1;

assign A1 = OperandA1_IN;
assign B1 = OperandB1_IN;

reg  [31:0] HI/*verilator public*/;
reg  [31:0] LO/*verilator public*/;
wire [31:0] HI_new1;
wire [31:0] LO_new1;
wire [31:0] new_HI;
wire [31:0] new_LO;

assign new_HI=HI_new1;
assign new_LO=LO_new1;


//***************************//***************************//********************

wire Request_Alt_PC1;
compare branch_compare1(
    .Jump(IF_all_info[98]),
    .OpA(A1),
    .OpB(B1),
    .Instr_input(Instr1_IN),
    .taken(Request_Alt_PC1));
//***************************//***************************//********************

ALU ALU1(
    .aluResult(ALU_result1),
    .HI_OUT(HI_new1),
    .LO_OUT(LO_new1),
    .HI_IN(HI),
    .LO_IN(LO),
    .A(A1),
    .B(B1),
    .ALU_control(ALU_Control1_IN),
    .shiftAmount(ShiftAmount1_IN),
    .CLK(!CLK)
    );


wire [31:0] MemWriteData1;

assign MemWriteData1 = MemWriteData1_IN;

reg take;
reg [31:0] addr;
integer instr_num_backup;
always @(posedge CLK) begin
    if(Instr1_PC_IN != 0) begin
        take <= Request_Alt_PC1;
        addr <= IF_all_info[92] ? A1 : IF_all_info[132:101];
        // instr_num_backup <= issue_instr_num;
    end
end


always @(posedge CLK or negedge RESET) begin
  	if(!RESET) begin
        Instr1_OUT <= 0;
        Instr1_PC_OUT <= 0;
        ALU_result1_OUT <= 0;
        WriteRegister1_OUT <= 0;
        MemWriteData1_OUT <= 0;
        RegWrite1_OUT <= 0;
        ALU_Control1_OUT <= 0;
        MemRead1_OUT <= 0;
        MemWrite1_OUT <= 0;
        Request_Alt_PC <= 0;
        all_info_MEM <= 0;
        $display("EXE:RESET");
  	end else if(CLK) begin
        HI <= new_HI;
        LO <= new_LO;
        Instr1_OUT <= Instr1_IN;
        Instr1_PC_OUT <= Instr1_PC_IN;
        ALU_result1_OUT <= ALU_result1;
        WriteRegister1_OUT <= WriteRegister1_IN;
        MemWriteData1_OUT <= MemWriteData1;
        RegWrite1_OUT <= RegWrite1_IN;
        ALU_Control1_OUT <= ALU_Control1_IN;
        MemRead1_OUT <= MemRead1_IN;
        MemWrite1_OUT <= MemWrite1_IN;
        Request_Alt_PC <= (Instr1_PC_IN != {32{1'b0}}) ? take : 0;
        alt_addr <= (Instr1_PC_IN != {32{1'b0}}) ? addr : 0;
        all_info_MEM <= IF_all_info;
        flush <= (Instr1_PC_IN != {32{1'b0}}) ? take : 0;





        //********************************************************************************************************
        // Request_Alt_PC      <= (Instr1_PC_IN != {32{1'b0}}) ? take : 0; //Request_Alt_PC1;//
        // alt_addr            <= (Instr1_PC_IN != {32{1'b0}}) ? addr : 0; //issue_jr_flag ? A1 : issue_alt_PC;//
        // all_info_MEM        <= IF_all_info;
        // flush               <= (Instr1_PC_IN != {32{1'b0}}) ? take : 0;
        // RegWr_flag_lsq      <= issue_RegWr_flag;
        // broadcast_flag      <= (instr_num_backup != issue_branch_flag) ? (Request_Alt_PC1 & issue_link_flag) : ((issue_instr_num != instr_num_backup) & issue_RegWr_flag & !MemRead1_IN & !issue_sys_flag);
        // broadcast_Map       <= issue_RegWr_map;
        // broadcast_val       <= ALU_result1;
        // exe_instr_num       <= issue_instr_num;
        // complete_flag_rob   <= !MemRead1_IN && !MemWrite1_IN;
        //********************************************************************************************************
		if(comment1) begin
                $display("EXE:Instr1=%x,Instr1_PC=%x,ALU_result1=%x; Write?%d to %d",Instr1_IN,Instr1_PC_IN,ALU_result1, RegWrite1_IN, WriteRegister1_IN);
                $display("Take: %x, Addr: %x, Request: %x, Alt addr: %x", take, addr, Request_Alt_PC, alt_addr);
                //$display("EXE:ALU_Control1=%x; MemRead1=%d; MemWrite1=%d (Data:%x)",ALU_Control1_IN, MemRead1_IN, MemWrite1_IN, MemWriteData1);
                // $display("EXE:OpA1=%x; OpB1=%x; HI=%x; LO=%x", A1, B1, new_HI,new_LO);
			end
	end
end

endmodule
