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
    input flush,

    // from exe
    input broadcast_flag,
    input [5:0] broadcast_map,
    input [4:0] broadcast_reg,
    input [31:0] broadcast_val,

    // from mem
    input [5:0] mem_broadcast_map,

    output halt,
    output reg [34:0] all_info_IF,

    // to exe
    output reg [5:0] issue_RegWr_map,
    output reg issue_RegWr_flag,
    output integer instr_num_exe,

    // to ROB
    output reg [169:0] all_info_ROB,
    output reg allocate_ROB,
    output integer instr_num_ROB,
    output reg [4:0] reg_wrt_ROB,
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
    output reg SYS);

//******************************************************************************
    wire [31:0] Instr1_IN;
    wire [31:0] Instr_PC_IN;
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
    /* verilator lint_off PINCONNECTEMPTY */
    .r_mapping(),
    /* verilator lint_on PINCONNECTEMPTY */
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
     .comment1(1)
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
    /* verilator lint_off PINCONNECTEMPTY */
    .r_mapping(),
    /* verilator lint_on PINCONNECTEMPTY */
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


    // wire [4:0]		RegA1;		//Register A
    // wire [4:0]		RegB1;		//Register B
    // wire [4:0]		WriteRegister1;	//Register to write
    // wire [31:0]	WriteRegisterRawVal1;
    // wire [31:0]	MemWriteData1;		//Data to write to memory
    // wire	[31:0]	OpA1;		//Operand A
    // wire [31:0]	OpB1;		//Operand B

    // wire [31:0]    rsRawVal1;
    // wire [31:0]    rtRawVal1;



    // assign WriteRegister1 = RegDst1?rd1:(link1?5'd31:rt1);
    // assign WriteRegister1 = oldC;
    // assign MemWriteData1 = WriteRegisterRawVal1;

    // assign OpA1 = rsRawVal1;
    // // assign RegA1 = link1?5'b00000:rs1;
    // assign RegA1 = oldA;

    //                    br                 link               opB                                rd                         opB
    // assign OpB1 = rename_out[97] ? (rename_out[100] ? rename_out[169:138] : rtRawVal1) : (rename_out[99] ? rtRawVal1 : rename_out[169:138]);
    // assign OpB1 = (rename_entry_issue[97] & rename_entry_issue[100]) ? rename_entry_issue[169:138] : (rename_entry_issue[99] ? rtRawVal1 : rename_entry_issue[169:138]);
    // assign OpB1 = (oldB == 0) ? rename_entry_issue[169:138] : rtRawVal1;
    // // assign RegB1 = RegDst1?rt1:5'd0;
    // assign RegB1 = oldB;

    //******************************************************************************


    wire [5:0] F_R [31:0];
    wire [5:0] R_F [31:0];
    wire [31:0] REGS [63:0];
    wire [5:0] returned_mapping;
    wire return_map;
    TABLE_obj #(.tag("FRAT")) FRAT
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        .reg_to_map(reg_to_map_FRAT),
        .new_mapping(new_mapping),
        .remap(remap_FRAT),
        .new_map(R_F),
        .overwrite(0),
        /* verilator lint_off PINCONNECTEMPTY */
        .returned_mapping(),
        .return_map(),
        /* verilator lint_off PINCONNECTEMPTY */
        .my_map(F_R));

    wire [4:0] temp_to_remap;
    wire [5:0] temp_map;
    wire temp_do;

    assign temp_to_remap = broadcast_flag ? broadcast_reg : WriteRegister1_IN;
    assign temp_map = broadcast_flag ? broadcast_map : mem_broadcast_map;
    assign temp_do = broadcast_flag | RegWrite1_IN;

    TABLE_obj #() RRAT
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        // .reg_to_map(broadcast_reg),
        // .new_mapping(broadcast_map),
        // .remap(broadcast_flag),
        // .reg_to_map(reg_to_map_FRAT),
        // .new_mapping(new_mapping),
        // .remap(remap_FRAT),
        .reg_to_map(temp_to_remap),
        .new_mapping(temp_map),
        .remap(temp_do),
        .new_map(F_R),
        .overwrite(0),
        .returned_mapping(returned_mapping),
        .return_map(return_map),
        .my_map(R_F));

    PHYS_REG #() PHYS_REG
        (.clk(CLK),
        .reset(RESET),
        .stall(0),
        // write exe
        .reg_to_update1(broadcast_map),
        .new_value1(broadcast_val),
        .update1(broadcast_flag),
        // write mem
        .reg_to_update2(mem_broadcast_map),
        .new_value2(WriteData1_IN),
        .update2(RegWrite1_IN),
        .regs(REGS));

    // assign rsRawVal1 = REGS[mappedS];
    // assign rtRawVal1 = REGS[mappedT];
    // assign WriteRegisterRawVal1 = REGS[mappedD];

    wire halt_rename_queue;

    wire [4:0] reg_to_map_FRAT;
    wire [5:0] new_mapping;
    wire remap_FRAT;

    wire [169:0] rename_entry_issue;
    wire rename_entry_issue_allocate;
    // wire [5:0] mappedS;
    // wire [5:0] mappedT;
    // wire [5:0] mappedD;
    wire [4:0] oldA;
    wire [4:0] oldB;
    wire [4:0] oldC;
    wire [63:0] busy;
    integer instr_num;
    // assign mappedS = rename_entry_issue[5:0];
    // assign mappedT = rename_entry_issue[11:6];
    // assign mappedD = rename_entry_issue[17:12];
    assign Instr1_IN         = rename_entry_issue[81:50];
    assign Instr_PC_IN       = rename_entry_issue[49:18];
    assign instr_num_ROB = instr_num;
    assign reg_wrt_ROB = oldC;
    Rename #() Rename
        (.CLK(CLK),
        .RESET(RESET),
        .STALL(halt_rename),
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

        .exe_busyclear_flag(temp_do),
        .exe_busyclear_reg(temp_map),

        .reg_to_map_FRAT(reg_to_map_FRAT),
        .new_mapping(new_mapping),
        .remap_FRAT(remap_FRAT),

        .entry_allocate_issue(rename_entry_issue_allocate),
        .entry_issue(rename_entry_issue),
        .busy(busy),

        .entry_ld_lsq(),
        .entry_st_lsq(),
        .entry_lsq(),

        .entry_allocate_ROB(all_info_ROB),
        .entry_ROB(allocate_ROB), // need

        .oldA(oldA),
        .oldB(oldB),
        .oldC(oldC),

        .halt_rename_queue(halt_rename_queue),

        .instr_num(instr_num));
//******************************************************************************


    Issue Issue(
        .CLK(CLK),
        .RESET(RESET),
        .STALL(bubble != 0),
        .FLUSH(flush),

        // RENAME inputs
        .rename_enque(rename_entry_issue_allocate),
        .rename_instr_num(instr_num),
        .rename_issueinfo(rename_entry_issue),
        .busy(busy),
        .rename_A(oldA),
        .rename_B(oldB),
        .rename_C(oldC),

        // EXE inputs
        .exe_broadcast(broadcast_flag),
        .exe_broadcast_map(broadcast_map),
        .exe_broadcast_val(broadcast_val),

        // phys reg input
        .PhysReg(REGS),

        // ROB inputs
        .rob_instr_num(0),

        // MEM inputs
        .mem_broadcast(RegWrite1_IN),
        .mem_broadcast_map(mem_broadcast_map),
        .mem_broadcast_val(WriteData1_IN),

        // outputs to EXE
        .RegWr_exe(RegWr_exe),
        .instr_exe(instr_exe),
        .instr_pc_exe(instr_pc_exe),
        .shamt_exe(shamt_exe),
        .ALU_con_exe(ALU_con_exe),
        .RegWr_flag_exe(RegWr_flag_exe),
        .MemWr_exe(MemWr_exe),
        .MemRd_exe(MemRd_exe),
        .branch_exe(branch_exe),
        .jump_exe(jump_exe),
        .jumpReg_exe(jumpReg_exe),
        .regDest_exe(regDest_exe),
        .link_exe(link_exe),
        .hilo_exe(hilo_exe),
        .sys_exe(sys_exe),
        .ALUSrc_exe(ALUSrc_exe),
        .alt_PC_exe(alt_PC_exe),
        .operandA1_exe(operandA1_exe),
        .operandB1_exe(operandB1_exe),
        .MemWriteData_exe(MemWriteData_exe),

        .A_exe(A_exe),
        .B_exe(B_exe),
        .C_exe(C_exe),
        .C_map_exe(C_map_exe),

        .instr_num_exe(instr_num_exe),

        .halt_rename(halt_rename));

    wire [5:0]    RegWr_exe;
    wire [31:0]   instr_exe;
    wire [31:0]   instr_pc_exe;

    wire [4:0]    shamt_exe;
    wire [5:0]    ALU_con_exe;
    wire          RegWr_flag_exe;
    wire          MemWr_exe;
    wire          MemRd_exe;
    wire          branch_exe;
    wire          jump_exe;
    wire          jumpReg_exe;
    wire          regDest_exe;
    wire          link_exe;
    wire [1:0]    hilo_exe;
    wire          sys_exe;
    wire          ALUSrc_exe;

    wire [31:0]   alt_PC_exe;
    wire [31:0]   operandA1_exe;
    wire [31:0]   operandB1_exe;
    wire [31:0]   MemWriteData_exe;

    wire [4:0]    A_exe;
    wire [4:0]    B_exe;
    wire [4:0]    C_exe;
    wire [5:0]    C_map_exe;

    wire          halt_rename;
    integer       instr_num_exe;

    reg [1:0] bubble;

    /* verilator lint_off PINCONNECTEMPTY */
        Decoder #(
        .TAG("1")
        )
        Decoder1 (
        .Instr(instr_exe),
        .Instr_PC(instr_pc_exe),
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
        /* verilator lint_on PINCONNECTEMPTY */

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
            issue_RegWr_map <= 0;
            issue_RegWr_flag <= 0;
            instr_num_exe <= 0;
            $display("ID:RESET");
        end else begin
            bubble <= bubble + 2'b1;
            Instr1_OUT <= instr_exe;
            OperandA1_OUT <= operandA1_exe;
            OperandB1_OUT <= operandB1_exe;
            ReadRegisterA1_OUT <= A_exe;
            ReadRegisterB1_OUT <= B_exe;
            WriteRegister1_OUT <= C_exe;
            MemWriteData1_OUT <= MemWriteData_exe;
            RegWrite1_OUT <= (C_exe != 5'd0) ? RegWr_flag_exe : 1'd0;
            ALU_Control1_OUT <= ALU_con_exe;
            MemRead1_OUT <= MemRd_exe;
            MemWrite1_OUT <= MemWr_exe;
            ShiftAmount1_OUT <= shamt_exe;
            Instr1_PC_OUT <= instr_pc_exe;
            SYS <= sys_exe;
            all_info_IF <= {alt_PC_exe, jumpReg_exe, jump_exe, link_exe};
            issue_RegWr_map <= C_map_exe;
            issue_RegWr_flag <= (C_exe != 5'd0) ? RegWr_flag_exe : 1'd0;
            instr_num_exe <= instr_num_exe;
        end
        if(1) begin
            $display("ID1:Instr=%x,Instr_PC=%x;SYS=%d()", Instr1_IN, Instr_PC_IN, rename_entry_issue[90]);
            $display("ID Flush: %x, Broadcast flag: %x, Broadcast Reg: %d, Broadcast Map: %d, Broadcast Val: %x", flush, broadcast_flag, broadcast_reg, broadcast_map, broadcast_val);
            //$display("ID1:A:Reg[%d]=%x; B:Reg[%d]=%x; Write?%d to %d",RegA1, OpA1, RegB1, OpB1, (WriteRegister1!=5'd0)?RegWrite1:1'd0, WriteRegister1);
            //$display("ID1:ALU_Control=%x; MemRead=%d; MemWrite=%d (%x); ShiftAmount=%d",ALU_control1, MemRead1, MemWrite1, MemWriteData1, shiftAmount1);
			  end
    end
endmodule
