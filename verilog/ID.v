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

    input [31:0] instr1_in,
    input [31:0] instr_pc_in,
    input [31:0] instr_pc_plus4_in,

    output halt,
    output reg [169:0] all_info_IF,
    input flush,
//******************************************************************************

    //Writeback stage [register to write]
    input[4:0]WriteRegister1_IN,
    //Data to write to register file
    input[31:0]WriteData1_IN,
    //Actually write to register file?
    input RegWrite1_IN,

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
    output WANT_FREEZE);

//******************************************************************************
    wire [31:0] Instr1_IN;
    wire [31:0] Instr_PC_IN;
    wire [31:0] Instr_PC_Plus4_IN;
    wire [63:0] deque_data;
    wire halt_IF;

    assign halt = halt_IF;

    QUEUE_obj #(.LENGTH(8), .WIDTH(64)) decode_queue
    (.clk(CLK),
    .reset(RESET),
    .stall(rename_halt),
    .flush(flush),
    .enque(1),
    .enque_data({instr_pc_in, instr1_in}),
    .deque(1),
    .deque_data(deque_data),
    .r_mapping(),
    .halt(halt_IF));

    wire link;
    wire rgdst;
    wire rgwrt;
    wire memrd;
    wire memwrt;
    wire [1:0] hilo;
    wire sys;
    wire jreg;
    wire [5:0] alucon;
    wire szextend;
    wire has_imm;
    wire br;
    wire jm;

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
    wire [31:0] ip4;
    wire [15:0] immed;
    wire [4:0]  shamt;
    wire [31:0] se_imm;
    wire [31:0] ze_imm;
    wire [31:0] se_sh_imm;
    wire [31:0] jm_dest_imm;
    wire [31:0] br_dest_imm;
    wire [31:0] next_addr;
    wire [31:0] opB;

    wire [63:0] instr_info;
    wire [14:0] regs;
    wire [18:0] controls;
    wire [68:0] constants;

    wire [166:0] rename_entry;
    wire [166:0] rename_queue_out;

    assign ip4 = deque_data[63:32] + 32'd4;
    assign se_sh_imm = {{14{immed[15]}}, immed, 2'b00};
    assign jm_dest_imm = {ip4[31:28], deque_data[31:0][25:0], 2'b00};
    assign br_dest_imm = ip4 + se_sh_imm;
    assign immed = deque_data[31:0][15:0];
    assign se_imm = {{16{immed[15]}}, immed};
    assign ze_imm = {{16{1'b0}}, immed};

    assign opB = br ? (link ? ip4 + 32'd4 : 0) : (rgdst ? 0 : (szextend ? se_imm : ze_imm));
    assign shamt = deque_data[31:0][10:6];
    assign next_addr = jm ? (jreg ? 0 : jm_dest_imm) : br_dest_imm;

    assign rs = ((link & !jreg) | (jm & !jreg)) ? 5'b00000 : deque_data[31:0][25:21];
    assign rt = rgdst ? deque_data[31:0][20:16] : 5'd00000;
    assign rd = rgdst ? deque_data[31:0][15:11] : (link ? 5'd31 : (jm ? 0 : deque_data[31:0][20:16]));
    assign instr_info = {deque_data[63:32], deque_data[31:0]};
    assign regs = {rs, rt, rd};
    assign controls = {link, rgdst, jm, br, memrd, memwrt, has_imm, rgwrt, jreg, szextend, sys, alucon, hilo};
    assign constants = {opB, shamt, next_addr};

    assign rename_entry = {constants, controls, instr_info, regs};

    QUEUE_obj #(.SPECIAL(0), .LENGTH(8), .WIDTH(167), .TAG("Rename Queue")) rename_queue
    (.clk(CLK),
    .reset(RESET),
    .stall(halt_rename_queue),
    .flush(flush),
    .enque(1),
    .enque_data(rename_entry),
    .deque(1),
    .deque_data(rename_queue_out),
    .r_mapping(),
    .halt(rename_halt));

    wire [4:0] keyS;
    wire [4:0] keyT;
    wire [4:0] keyD;
    wire [31:0] rq_instr_r;
    wire [31:0] rq_ipc_r;
    assign keyS = rename_queue_out[14:10];
    assign keyT = rename_queue_out[9:5];
    assign keyD = rename_queue_out[4:0];
    assign rq_instr_r = rename_queue_out[46:15];
    assign rq_ipc_r = rename_queue_out[78:47];



//******************************************************************************


    wire [4:0]		RegA1;		//Register A
    wire [4:0]		RegB1;		//Register B
    wire [4:0]		WriteRegister1;	//Register to write
    wire [31:0]	WriteRegisterRawVal1;
    wire [31:0]	MemWriteData1;		//Data to write to memory
    wire	[31:0]	OpA1;		//Operand A
    wire [31:0]	OpB1;		//Operand B

    wire [31:0]    rsRawVal1;
    wire [31:0]    rtRawVal1;



    // assign WriteRegister1 = RegDst1?rd1:(link1?5'd31:rt1);
    assign WriteRegister1 = oldC;
    assign MemWriteData1 = WriteRegisterRawVal1;

    //OpA will always be rsval, although it might be unused.
    assign OpA1 = rsRawVal1;
    // assign RegA1 = link1?5'b00000:rs1;
    assign RegA1 = oldA;
    //When we branch/jump and link, OpB needs to store return address
    //Otherwise, if we have writeregister==rd, then rt is used for OpB.
    //if writeregister!=rd, then writeregister ==rt, and we use immediate instead.
    //                    br                 link               opB                                rd                         opB
    // assign OpB1 = rename_out[97] ? (rename_out[100] ? rename_out[169:138] : rtRawVal1) : (rename_out[99] ? rtRawVal1 : rename_out[169:138]);
    assign OpB1 = (rename_out[97] & rename_out[100]) ? rename_out[169:138] : (rename_out[99] ? rtRawVal1 : rename_out[169:138]);
    // assign RegB1 = RegDst1?rt1:5'd0;
    assign RegB1 = oldB;

    //******************************************************************************


    wire [5:0] F_R [31:0];
    wire [5:0] R_F [31:0];
    wire [31:0] REGS [63:0];
    wire [5:0] returned_mapping;
    wire return_map;
    TABLE_obj #() FRAT
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        .reg_to_map(reg_to_map_FRAT),
        .new_mapping(new_mapping),
        .remap(remap_FRAT),
        .new_map(R_F),
        .overwrite(0),
        .returned_mapping(),
        .return_map(),
        .my_map(F_R));

    TABLE_obj #() RRAT
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        .reg_to_map(reg_to_map_FRAT),
        .new_mapping(new_mapping),
        .remap(remap_FRAT),
        .new_map(F_R),
        .overwrite(0),
        .returned_mapping(returned_mapping),
        .return_map(return_map),
        .my_map(R_F));

    PHYS_REG #() PHYS_REG
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        .reg_to_update(F_R[WriteRegister1_IN]),
        .new_value(WriteData1_IN),
        .update(RegWrite1_IN),
        .regs(REGS));

    assign rsRawVal1 = REGS[mappedS];
    assign rtRawVal1 = REGS[mappedT];
    assign WriteRegisterRawVal1 = REGS[mappedD];

    wire halt_rename_queue;

    wire [4:0] reg_to_map_FRAT;
    wire [5:0] new_mapping;
    wire remap_FRAT;

    wire rrat_free;
    wire [5:0] rrat_free_reg;

    wire [169:0] rename_out;
    wire [5:0] mappedS;
    wire [5:0] mappedT;
    wire [5:0] mappedD;
    wire [4:0] oldA;
    wire [4:0] oldB;
    wire [4:0] oldC;
    assign mappedS = rename_out[5:0];
    assign mappedT = rename_out[11:6];
    assign mappedD = rename_out[17:12];
    assign Instr1_IN         = rename_out[81:50];
    assign Instr_PC_IN       = rename_out[49:18];
    assign Instr_PC_Plus4_IN = rename_out[49:18] + 32'd4;

    Rename #() Rename
        (.CLK(CLK),
        .RESET(RESET),
        .STALL(bubble != 0),
        .FLUSH(flush),

        .id_instr(rq_instr_r),
        .id_instrpc(rq_ipc_r),
        .id_RegA(keyS),
        .id_RegB(keyT),
        .id_RegWr(keyD),
        .id_control(rename_queue_out[166:79]),

        .frat_my_map(F_R),

        .rrat_free(return_map),
        .rrat_free_reg(returned_mapping),
        .rrat_map(R_F),

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

        .oldA(oldA),
        .oldB(oldB),
        .oldC(oldC),

        .halt_rename_queue(halt_rename_queue),

        .instr_num());

//******************************************************************************
    Decoder #(
    .TAG("1")
    )
    Decoder1 (
    .Instr(Instr1_IN),
    .Instr_PC(Instr_PC_IN),
    .Link(),
    .RegDest(),
    .Jump(),
    .Branch(),
    .MemRead(),
    .MemWrite(),
    .ALUSrc(),
    .RegWrite(),
    .JumpRegister(),
    .SignOrZero(),
    .Syscall(),
    .ALUControl(),
    .MultRegAccess(),   //Needed for out-of-order
     .comment1(1)
    );

    Issue Issue(
        .CLK(CLK),
        .RESET(RESET),
        .STALL(STALL),
        .FLUSH(flush),

        // RENAME inputs
        .rename_enque(0),
        .rename_instr_num(0),
        .rename_issueinfo(0),
        .busy(0),

        // EXE inputs
        .exe_broadcast(0),
        .exe_broadcast_map(0),
        .exe_broadcast_val(0),

        // phys reg input
        .PhysReg(REGS),

        // ROB inputs
        .rob_instr_num(0),

        // MEM inputs
        .mem_broadcast(0),
        .mem_broadcast_map(0),
        .mem_broadcast_val(0),

        // outputs to EXE
        .RegWr_exe(),
        .instr_exe(),
        .instr_pc_exe(),
        .shamt_exe(),
        .ALU_con_exe(),
        .RegWr_flag_exe(),
        .MemWr_exe(),
        .MemRd_exe(),
        .branch_exe(),
        .jump_exe(),
        .jumpReg_exe(),
        .regDest_exe(),
        .link_exe(),
        .hilo_exe(),
        .sys_exe(),
        .ALUSrc_exe(),
        .alt_PC_exe(),
        .operandA1_exe(),
        .operandB1_exe(),
        .MemWriteData_exe(),
        .instr_num_exe(),

        .halt_rename());

    reg [1:0] bubble;

    always @(posedge CLK or negedge RESET) begin
        if(!RESET) begin
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
            bubble <= 0;
            all_info_IF <= 0;
            $display("ID:RESET");
        end else begin
        bubble <= bubble + 2'b1;
        if(bubble == 0) begin
            Instr1_OUT <= Instr1_IN;
            OperandA1_OUT <= OpA1;
            OperandB1_OUT <= OpB1;
            ReadRegisterA1_OUT <= RegA1;
            ReadRegisterB1_OUT <= RegB1;
            WriteRegister1_OUT <= WriteRegister1;
            MemWriteData1_OUT <= MemWriteData1;
            RegWrite1_OUT <= (WriteRegister1 != 5'd0) ? rename_out[93] : 1'd0;
            ALU_Control1_OUT <= rename_out[89:84];
            MemRead1_OUT <= rename_out[96];
            MemWrite1_OUT <= rename_out[95];
            ShiftAmount1_OUT <= rename_out[137:133];
            Instr1_PC_OUT <= Instr_PC_IN;
            SYS <= rename_out[90];
            all_info_IF <= rename_out[169:0];
        end
        else begin
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
            all_info_IF <= 0;
        end
        if(1) begin
            $display("ID1:Instr=%x,Instr_PC=%x;SYS=%d()", Instr1_IN, Instr_PC_IN, rename_out[90]);
            $display("ID Flush: %x", flush);
            //$display("ID1:A:Reg[%d]=%x; B:Reg[%d]=%x; Write?%d to %d",RegA1, OpA1, RegB1, OpB1, (WriteRegister1!=5'd0)?RegWrite1:1'd0, WriteRegister1);
            //$display("ID1:ALU_Control=%x; MemRead=%d; MemWrite=%d (%x); ShiftAmount=%d",ALU_control1, MemRead1, MemWrite1, MemWriteData1, shiftAmount1);
			  end
    end
end
endmodule
