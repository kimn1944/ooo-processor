`include "config.v"
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    21:49:08 10/16/2013
// Design Name:
// Module Name:    ID2
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
module ID(
    input CLK,
    input RESET,
//******************************************************************************
	 // //Instruction from Fetch
   //  input[31:0]Instr1_IN,
	 // //PC of instruction fetched
   //  input[31:0]Instr_PC_IN,
   //  //PC+4 of instruction fetched (needed for various things)
   //  input[31:0]Instr_PC_Plus4_IN,

   input [31:0] instr1_in,
   input [31:0] instr_pc_in,
   input [31:0] instr_pc_plus4_in,

   output halt,
//******************************************************************************

    //Writeback stage [register to write]
	 input[4:0]WriteRegister1_IN,
	 //Data to write to register file
	 input[31:0]WriteData1_IN,
	 //Actually write to register file?
	 input RegWrite1_IN,

	 //Alternate PC for next fetch (branch/jump destination)
    output reg [31:0]Alt_PC,
    //Actually use alternate PC
    output reg Request_Alt_PC,

    //Instruction being passed to EXE [debug]
     output reg [31:0]Instr1_OUT,
    //PC of instruction being passed to EXE [debug]
     output reg [31:0]Instr1_PC_OUT,
     //OperandA passed to EXE
    output reg [31:0]OperandA1_OUT,
     //OperandB passed to EXE
    output reg [31:0]OperandB1_OUT,
     //RegisterA passed to EXE
    output reg [4:0]ReadRegisterA1_OUT,
     //RegisterB passed to EXE
    output reg [4:0]ReadRegisterB1_OUT,
     //Destination Register passed to EXE
    output reg [4:0]WriteRegister1_OUT,
     //Data to write to memory passed to EXE [for store]
     output reg [31:0]MemWriteData1_OUT,
     //we'll be writing to a register... passed to EXE
    output reg RegWrite1_OUT,
    //ALU control passed to EXE
    output reg [5:0]ALU_Control1_OUT,
    //This is a memory read (passed to EXE)
    output reg MemRead1_OUT,
    //This is a memory write (passed to EXE)
    output reg MemWrite1_OUT,
    //Shift amount [for ALU functions] (passed to EXE)
    output reg [4:0]ShiftAmount1_OUT,

	 //Tell the simulator to process a system call
	 output reg SYS,
	 //Tell fetch to stop advancing the PC, and wait.
	 output WANT_FREEZE
    );

//******************************************************************************
wire [31:0] Instr1_IN;
wire [31:0] Instr_PC_IN;
wire [31:0] Instr_PC_Plus4_IN;
wire [63:0] deque_data;
wire halt_IF;

assign halt = !Request_Alt_PC && halt_IF;

    QUEUE_obj #(.LENGTH(8), .WIDTH(64)) decode_queue
    (.clk(CLK),
    .reset(RESET),
    .stall(rename_halt),
    .flush(Request_Alt_PC),
    .enque(1),
    .enque_data({instr_pc_in, instr1_in}),
    .deque(1),
    .deque_data(deque_data),
    .halt(halt_IF));

    wire link;
    wire rgdst;
    wire rgwrt;
    wire memrd;
    wire memwrt;
    wire [1:0] hilo;
    // wire hilowrt;
    wire sys;
    wire jreg;
    wire [5:0] alucon;
    wire szextend;
    wire has_imm;
    wire br;
    wire jm;

    // assign hilowrt = (deque_data[31:0][31:26] == 6'b000000) ? ((deque_data[31:0][5:0] == 6'b010001 || deque_data[31:0][5:0] == 6'b010011) ? 1 : 0) : 0;
    Decoder #(
    .TAG("2")
    )
    Decoder2 (
    .Instr(deque_data[31:0]),
    .Instr_PC(deque_data[63:32]),
    .Link(link),
    .RegDest(rgdst),
    .Jump(jm),
    .Branch(br),
    .MemRead(memrd),
    .MemWrite(memwrt),
    .ALUSrc(has_imm),
    .RegWrite(rgwrt),
    .JumpRegister(jreg),
    .SignOrZero(szextend),
    .Syscall(sys),
    .ALUControl(alucon),
    .MultRegAccess(hilo),   //Needed for out-of-order
     .comment1(0)
    );

    wire rename_halt;
    wire [4:0] rs;
    wire [4:0] rt;
    wire [4:0] rd;
    wire [15:0] immed;
    wire [4:0]  shamt;
    wire [31:0] se_imm;
    wire [31:0] ze_imm;

    wire [63:0] instr_info;
    wire [14:0] regs;
    wire [18:0]  controls;
    wire [84:0] constants;

    wire [182:0] rename_entry;
    wire [182:0] rename_queue_out;


    assign immed = deque_data[31:0][15:0];
    assign shamt = deque_data[31:0][10:6];
    assign se_imm = {{16{immed[15]}}, immed};
    assign ze_imm = {{16{1'b0}}, immed};
    assign rs = (link & !jreg) ? 5'b00000 : deque_data[31:0][25:21];
    assign rt = rgdst ? deque_data[31:0][20:16] : 5'd00000;
    assign rd = rgdst ? deque_data[31:0][15:11] : (link ? 5'd31 : deque_data[31:0][20:16]);
    assign instr_info = {deque_data[63:32], deque_data[31:0]};
    assign regs = {rs, rt, rd};
    assign controls = {link, rgdst, jm, br, memrd, memwrt, has_imm, rgwrt, jreg, szextend, sys, alucon, hilo};
    assign constants = {shamt, immed, se_imm, ze_imm};

    assign rename_entry = {instr_info, regs, controls, constants};

    QUEUE_obj #(.SPECIAL(1), .LENGTH(8), .WIDTH(183), .TAG("Rename Queue")) rename_queue
    (.clk(CLK),
    .reset(RESET),
    .stall(bubble != 0),
    .flush(Request_Alt_PC),
    .enque(1),
    .enque_data(rename_entry),
    .deque(1),
    .deque_data(rename_queue_out),
    .halt(rename_halt));

    wire [4:0] keyS;
    wire [4:0] keyT;
    wire [4:0] keyD;
    wire [31:0] rq_instr_r;
    wire [31:0] rq_ipc_r;
    assign keyS = rename_queue_out[118:114];
    assign keyT = rename_queue_out[113:109];
    assign keyD = rename_queue_out[108:104];
    assign rq_instr_r = rename_queue_out[150:119];
    assign rq_ipc_r = rename_queue_out[182:151];
    assign Instr1_IN         = rename_queue_out[150:119];
    assign Instr_PC_IN       = rename_queue_out[182:151];
    assign Instr_PC_Plus4_IN = rename_queue_out[182:151] + 32'd4;



//******************************************************************************
	 wire [5:0]	ALU_control1;	//async. ALU_Control output
	 wire			link1;			//whether this is a "And Link" instruction
	 wire			RegDst1;			//whether this instruction uses the "rd" register (Instr[15:11])
	 wire			jump1;			//whether we unconditionally jump
	 wire			branch1;			//whether we are branching
	 wire			MemRead1;		//whether this instruction is a load
	 wire			MemWrite1;		//whether this instruction is a store
	 /*verilator lint_off UNUSED */
	 //We don't need this now.
	 wire			ALUSrc1;			//whether this instruction uses an immediate
	 /*verilator lint_on UNUSED */
	 wire			RegWrite1;		//whether we want to write to a register with this instruction (do_writeback)
	 wire			jumpRegister_Flag1;	//this is a Jump Register function (also set for other functions; vestige of previous code)
	 wire			sign_or_zero_Flag1;	//If 1, we use sign-extended immediate; otherwise, 0-extended immediate.
	 wire			syscal1;			//If this instruction is a syscall
	 wire			comment1;
	 assign		comment1 = 1;

	 wire			Request_Alt_PC1;	//Do we want to branch/jump?
	 wire	[31:0]	Alt_PC1;	//address to which we branch/jump

	 wire [4:0]		RegA1;		//Register A
	 wire [4:0]		RegB1;		//Register B
	 wire [4:0]		WriteRegister1;	//Register to write
	 wire [31:0]	WriteRegisterRawVal1;
	 wire [31:0]	MemWriteData1;		//Data to write to memory
	 wire	[31:0]	OpA1;		//Operand A
	 wire [31:0]	OpB1;		//Operand B

     wire [4:0]     rs1;     //also format1
     wire [31:0]    rsRawVal1;
     wire   [31:0]  rsval1;
     wire   [4:0]       rt1;
     wire [31:0]    rtRawVal1;
     wire   [31:0]  rtval1;
     wire [4:0]     rd1;
     wire [4:0]     shiftAmount1;
     wire [15:0]    immediate1;

     assign rs1 = Instr1_IN[25:21];
     assign rt1 = Instr1_IN[20:16];
     assign rd1 = Instr1_IN[15:11];
     assign shiftAmount1 = Instr1_IN[10:6];
     assign immediate1 = Instr1_IN[15:0];

//Begin branch/jump calculation

    wire [31:0] rsval_jump1;
    assign rsval_jump1 = rsRawVal1;

NextInstructionCalculator NIA1 (
    .Instr_PC_Plus4(Instr_PC_Plus4_IN),
    .Instruction(Instr1_IN),
    .Jump(jump1),
    .JumpRegister(jumpRegister_Flag1),
    .RegisterValue(rsval_jump1),
    .NextInstructionAddress(Alt_PC1),
	 .Register(rs1)
    );

     wire [31:0]    signExtended_immediate1;
     wire [31:0]    zeroExtended_immediate1;

     assign signExtended_immediate1 = {{16{immediate1[15]}},immediate1};
     assign zeroExtended_immediate1 = {{16{1'b0}},immediate1};

compare branch_compare1 (
    .Jump(jump1),
    .OpA(OpA1),
    .OpB(OpB1),
    .Instr_input(Instr1_IN),
    .taken(Request_Alt_PC1)
    );
//End branch/jump calculation

assign rsval1 = rsRawVal1;
assign rtval1 = rtRawVal1;


	// assign WriteRegister1 = RegDst1?rd1:(link1?5'd31:rt1);
  assign WriteRegister1 = keyD;
  assign MemWriteData1 = WriteRegisterRawVal1;

	//OpA will always be rsval, although it might be unused.
	assign OpA1 = link1?0:rsval1;
	// assign RegA1 = link1?5'b00000:rs1;
  assign RegA1 = keyS;
	//When we branch/jump and link, OpB needs to store return address
	//Otherwise, if we have writeregister==rd, then rt is used for OpB.
	//if writeregister!=rd, then writeregister ==rt, and we use immediate instead.
	assign OpB1 = branch1 ? (link1 ? (Instr_PC_Plus4_IN+4) : rtval1) : (RegDst1 ? rtval1 : (sign_or_zero_Flag1 ? signExtended_immediate1 : zeroExtended_immediate1));
	// assign RegB1 = RegDst1?rt1:5'd0;
  assign RegB1 = keyT;

//******************************************************************************
wire [5:0] F_R [31:0];
wire [5:0] R_F [31:0];
wire [31:0] REGS [63:0];

`ifdef REMAP
    TABLE_obj #() FRAT
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        // .reg_to_map(reg_to_map_FRAT),
        // .new_mapping(new_mapping),
        // .remap(remap_FRAT),
        .reg_to_map(0),
        .new_mapping(0),
        .remap(0),
        .new_map(R_F),
        .overwrite(0),
        .my_map(F_R));

    TABLE_obj #() RRAT
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        .reg_to_map(0),
        .new_mapping(0),
        .remap(0),
        .new_map(F_R),
        .overwrite(0),
        .my_map(R_F));

    PHYS_REG #() PHYS_REG
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        .reg_to_update(F_R[WriteRegister1_IN]),
        .new_value(WriteData1_IN),
        .update(RegWrite1_IN),
        .regs(REGS));

    assign rsRawVal1 = REGS[F_R[keyS]];
    assign rtRawVal1 = REGS[F_R[keyT]];
    assign WriteRegisterRawVal1 = REGS[F_R[keyD]];
    // assign rsRawVal1 = REGS[mappedS];
    // assign rtRawVal1 = REGS[mappedT];
    // assign WriteRegisterRawVal1 = REGS[mappedD];

    wire halt_rename_queue;

    wire [4:0] reg_to_map_FRAT;
    wire [5:0] new_mapping;
    wire remap_FRAT;

    wire rrat_free;
    wire [5:0] rrat_free_reg;

    wire [185:0] rename_out;
    wire [5:0] mappedS;
    wire [5:0] mappedT;
    wire [5:0] mappedD;
    assign mappedS = rename_out[5:0];
    assign mappedT = rename_out[11:6];
    assign mappedD = rename_out[17:12];
    // assign Instr1_IN         = rename_out[81:50];
    // assign Instr_PC_IN       = rename_out[49:18];
    // assign Instr_PC_Plus4_IN = rename_out[49:18] + 32'd4;
    // assign keyS = rename_out[118:114];
    // assign keyT = rename_out[113:109];
    // assign keyD = rename_out[108:104];
    Rename #() Rename
        (.CLK(CLK),
        .RESET(RESET),
        .STALL(0),
        .FLUSH(0),

        .id_instr(rq_instr_r),
        .id_instrpc(rq_ipc_r),
        .id_RegA(keyS),
        .id_RegB(keyT),
        .id_RegWr(keyD),
        .id_control(rename_queue_out[103:0]),

        .frat_my_map(F_R),

        .rrat_free(rrat_free),
        .rrat_free_reg(rrat_free_reg),

        .issue_halt(0),
        .lsq_halt(0),
        .rob_halt(0),

        .exe_busyclear_flag(),
        .exe_busyclear_reg(),

        .reg_to_map_FRAT(reg_to_map_FRAT),
        .new_mapping(new_mapping),
        .remap_FRAT(remap_FRAT),

        .entry_allocate_issue(),
        .entry_issue(),
        .busy(),

        .entry_ld_lsq(),
        .entry_st_lsq(),
        .entry_lsq(),

        .entry_allocate_ROB(),
        .entry_ROB(rename_out), // need

        .halt_rename_queue(halt_rename_queue),

        .instr_num());

`else
    RegFile RegFile (
        .CLK(CLK),
        .RESET(RESET),
        .RegA1(rs1),
        .RegB1(rt1),
        .RegC1(WriteRegister1),
        .DataA1(rsRawVal1),
        .DataB1(rtRawVal1),
        .DataC1(WriteRegisterRawVal1),
        .WriteReg1(WriteRegister1_IN),
        .WriteData1(WriteData1_IN),
        .Write1(RegWrite1_IN)
        );

`endif
//******************************************************************************

	 reg FORCE_FREEZE;
	 reg INHIBIT_FREEZE;
     assign WANT_FREEZE = ((FORCE_FREEZE | syscal1) && !INHIBIT_FREEZE);

reg [1:0] bubble;

always @(posedge CLK or negedge RESET) begin
	if(!RESET) begin
		Alt_PC <= 0;
		Request_Alt_PC <= 0;
		Instr1_OUT <= 0;
		OperandA1_OUT <= 0;
		OperandB1_OUT <= 0;
		ReadRegisterA1_OUT <= 0;
		ReadRegisterB1_OUT <= 0;
		WriteRegister1_OUT <= 0;
		MemWriteData1_OUT <= 0;
		RegWrite1_OUT <= 0;
		ALU_Control1_OUT <= 0;
		MemRead1_OUT <= 0;
		MemWrite1_OUT <= 0;
		ShiftAmount1_OUT <= 0;
		Instr1_PC_OUT <= 0;
		SYS <= 0;
		FORCE_FREEZE <= 0;
		INHIBIT_FREEZE <= 0;
    bubble <= 0;
	$display("ID:RESET");
	end else begin
      bubble <= bubble + 2'b1;
      if(bubble == 0) begin
          Alt_PC <= Alt_PC1;
          Request_Alt_PC <= Request_Alt_PC1;
          Instr1_OUT <= Instr1_IN;
          OperandA1_OUT <= OpA1;
          OperandB1_OUT <= OpB1;
          ReadRegisterA1_OUT <= RegA1;
          ReadRegisterB1_OUT <= RegB1;
          WriteRegister1_OUT <= WriteRegister1;
          MemWriteData1_OUT <= MemWriteData1;
          RegWrite1_OUT <= (WriteRegister1 != 5'd0) ? RegWrite1 : 1'd0;
          ALU_Control1_OUT <= ALU_control1;
          MemRead1_OUT <= MemRead1;
          MemWrite1_OUT <= MemWrite1;
          ShiftAmount1_OUT <= shiftAmount1;
          Instr1_PC_OUT <= Instr_PC_IN;
          SYS <= syscal1;
      end
      else begin
          Alt_PC <= 0;
          Request_Alt_PC <= 0;
          Instr1_OUT <= 0;
          OperandA1_OUT <= 0;
          OperandB1_OUT <= 0;
          ReadRegisterA1_OUT <= 0;
          ReadRegisterB1_OUT <= 0;
          WriteRegister1_OUT <= 0;
          MemWriteData1_OUT <= 0;
          RegWrite1_OUT <= 0;
          ALU_Control1_OUT <= 0;
          MemRead1_OUT <= 0;
          MemWrite1_OUT <= 0;
          ShiftAmount1_OUT <= 0;
          Instr1_PC_OUT <= 0;
          SYS <= 0;
      end
			if(comment1) begin
          $display("ID1:Instr=%x,Instr_PC=%x,Req_Alt_PC=%d:Alt_PC=%x;SYS=%d()",Instr1_IN,Instr_PC_IN,Request_Alt_PC1,Alt_PC1,syscal1);
          //$display("ID1:A:Reg[%d]=%x; B:Reg[%d]=%x; Write?%d to %d",RegA1, OpA1, RegB1, OpB1, (WriteRegister1!=5'd0)?RegWrite1:1'd0, WriteRegister1);
          //$display("ID1:ALU_Control=%x; MemRead=%d; MemWrite=%d (%x); ShiftAmount=%d",ALU_control1, MemRead1, MemWrite1, MemWriteData1, shiftAmount1);
			end
	end
end

    Decoder #(
    .TAG("1")
    )
    Decoder1 (
    .Instr(Instr1_IN),
    .Instr_PC(Instr_PC_IN),
    .Link(link1),
    .RegDest(RegDst1),
    .Jump(jump1),
    .Branch(branch1),
    .MemRead(MemRead1),
    .MemWrite(MemWrite1),
    .ALUSrc(ALUSrc1),
    .RegWrite(RegWrite1),
    .JumpRegister(jumpRegister_Flag1),
    .SignOrZero(sign_or_zero_Flag1),
    .Syscall(syscal1),
    .ALUControl(ALU_control1),
/* verilator lint_off PINCONNECTEMPTY */
    .MultRegAccess(),   //Needed for out-of-order
/* verilator lint_on PINCONNECTEMPTY */
     .comment1(1'b1)
    );

endmodule
