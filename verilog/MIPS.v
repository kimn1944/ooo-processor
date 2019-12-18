`include "config.v"
//-----------------------------------------
//            Pipelined MIPS
//-----------------------------------------
/* verilator lint_off BLKSEQ */
module MIPS (

    input RESET,
    input CLK,

    //The physical memory address we want to interact with
    output [31:0] data_address_2DM,
    //We want to perform a read?
    output MemRead_2DM,
    //We want to perform a write?
    output MemWrite_2DM,

    //Data being read
    input [31:0] data_read_fDM,
    //Data being written
    output [31:0] data_write_2DM,
    //How many bytes to write:
        // 1 byte: 1
        // 2 bytes: 2
        // 3 bytes: 3
        // 4 bytes: 0
    output [1:0] data_write_size_2DM,

    //Data being read
    input [255:0] block_read_fDM,
    //Data being written
    output [255:0] block_write_2DM,
    //Request a block read
    output dBlkRead,
    //Request a block write
    output dBlkWrite,
    //Block read is successful (meets timing requirements)
    input block_read_fDM_valid,
    //Block write is successful
    input block_write_fDM_valid,

    //Instruction to fetch
    output [31:0] Instr_address_2IM,
    //Instruction fetched at Instr_address_2IM
    input [31:0] Instr1_fIM,
    //Instruction fetched at Instr_address_2IM+4 (if you want superscalar)
    input [31:0] Instr2_fIM,

    //Cache block of instructions fetched
    input [255:0] block_read_fIM,
    //Block read is successfull
    input block_read_fIM_valid,
    //Request a block read
    output iBlkRead,

    //Tell the simulator that everything's ready to go to process a syscall.
    //Make sure that all register data is flushed to the register file, and that
    //all data cache lines are flushed and invalidated.
    output SYS
    );


//Connecting wires between IF and ID
    wire [31:0] Instr1_IFID;
    wire [31:0] Instr_PC_IFID;


//Connecting wires between IC and IF
    wire [31:0] Instr_address_2IC/*verilator public*/;
    //Instr_address_2IC is verilator public so that sim_main can give accurate
    //displays.
    //We could use Instr_address_2IM, but this way sim_main doesn't have to
    //worry about whether or not a cache is present.
    wire [31:0] Instr1_fIC;
    wire [31:0] Instr2_fIC;
    assign Instr_address_2IM = Instr_address_2IC;
    assign Instr1_fIC = Instr1_fIM;
    assign Instr2_fIC = Instr2_fIM;
    assign iBlkRead = 1'b0;
    /*verilator lint_off UNUSED*/
    wire [255:0] unused_i1;
    wire unused_i2;
    /*verilator lint_on UNUSED*/
    assign unused_i1 = block_read_fIM;
    assign unused_i2 = block_read_fIM_valid;
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i3;
    /*verilator lint_on UNUSED*/
    assign unused_i3 = Instr2_fIC;

    IF IF(
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_OUT(Instr1_IFID),
        .Instr_PC_OUT(Instr_PC_IFID),
        /* verilator lint_off PINCONNECTEMPTY */
        .Instr_PC_Plus4(),
        /* verilator lint_off PINCONNECTEMPTY */
        .STALL(halt),
        .Request_Alt_PC(request_alt_pc),
        .Alt_PC(alt_addr),
        .Instr_address_2IM(Instr_address_2IC),
        .Instr1_fIM(Instr1_fIC)
    );


    wire [4:0]  WriteRegister1_MEMWB;
    wire [31:0] WriteData1_MEMWB;
    wire        RegWrite1_MEMWB;

    wire [31:0] Instr1_IDEXE;
    wire [31:0] Instr1_PC_IDEXE;
    wire [31:0] OperandA1_IDEXE;
    wire [31:0] OperandB1_IDEXE;
    wire [4:0]  WriteRegister1_IDEXE;
    wire [31:0] MemWriteData1_IDEXE;
    wire        RegWrite1_IDEXE;
    wire [5:0]  ALU_Control1_IDEXE;
    wire        MemRead1_IDEXE;
    wire        MemWrite1_IDEXE;
    wire [4:0]  ShiftAmount1_IDEXE;

    wire [34:0] IF_all_info_EXE;
    integer instr_num_exe;

    wire halt;

    wire [169:0] all_info_ROB;
    wire allocate_ROB;
    integer instr_num_ROB;
    wire [4:0] reg_wrt_ROB;

	ID ID(
		.CLK(CLK),
		.RESET(RESET),
//******************************************************************************
    .instr1_in(Instr1_IFID),
    .instr_pc_in(Instr_PC_IFID),
    .halt(halt),
    .all_info_IF(IF_all_info_EXE),
    .flush(flush),

    // from exe
    .broadcast_flag(exe_broadcast_flag),
    .broadcast_map(exe_broadcast_map),
    .broadcast_val(exe_broadcast_val),
    .broadcast_reg(exe_broadcast_reg),

    // to exe
    .issue_RegWr_map(issue_RegWr_map),
    .issue_RegWr_flag(issue_RegWr_flag),
    .instr_num_exe(instr_num_exe),

    // to rob
    .all_info_ROB(all_info_ROB),
    .allocate_ROB(allocate_ROB),
    .instr_num_ROB(instr_num_ROB),
    .reg_wrt_ROB(reg_wrt_ROB),

    // from MEM
    .mem_broadcast_map(mem_broadcast_map),
//******************************************************************************
		.WriteRegister1_IN(WriteRegister1_MEMWB),
		.WriteData1_IN(WriteData1_MEMWB),
		.RegWrite1_IN(RegWrite1_MEMWB),
		.Instr1_OUT(Instr1_IDEXE),
        .Instr1_PC_OUT(Instr1_PC_IDEXE),
		.OperandA1_OUT(OperandA1_IDEXE),
		.OperandB1_OUT(OperandB1_IDEXE),
/* verilator lint_off PINCONNECTEMPTY */
        .ReadRegisterA1_OUT(),
        .ReadRegisterB1_OUT(),
/* verilator lint_on PINCONNECTEMPTY */
		.WriteRegister1_OUT(WriteRegister1_IDEXE),
		.MemWriteData1_OUT(MemWriteData1_IDEXE),
		.RegWrite1_OUT(RegWrite1_IDEXE),
		.ALU_Control1_OUT(ALU_Control1_IDEXE),
		.MemRead1_OUT(MemRead1_IDEXE),
		.MemWrite1_OUT(MemWrite1_IDEXE),
		.ShiftAmount1_OUT(ShiftAmount1_IDEXE),

		.SYS(SYS)
	);

    wire [31:0] Instr1_EXEMEM;
    wire [31:0] Instr1_PC_EXEMEM;
    wire [31:0] ALU_result1_EXEMEM;
    wire [4:0]  WriteRegister1_EXEMEM;
    wire [31:0] MemWriteData1_EXEMEM;
    wire        RegWrite1_EXEMEM;
    wire [5:0]  ALU_Control1_EXEMEM;
    wire        MemRead1_EXEMEM;
    wire        MemWrite1_EXEMEM;

    wire request_alt_pc;
    wire [31:0] alt_addr;
    wire flush;
    wire [169:0] EXE_all_info_MEM;

    //******************************************************************************
    wire [5:0] issue_RegWr_map;
    wire issue_RegWr_flag;
    wire exe_broadcast_flag;
    wire [5:0] exe_broadcast_map;
    wire [31:0] exe_broadcast_val;
    wire [4:0] exe_broadcast_reg;

    wire [5:0] exe_RegWr_map;


    ROB ROB (
        .clk(CLK),
        .reset(RESET),
        .stall(0),

        .rename_enque(allocate_ROB),
        .rename_instr_num(instr_num_ROB),
        .rename_RegWr(reg_wrt_ROB),
        .rename_enque_data(all_info_ROB),

        .exe_complete_flag(0),
        .exe_broadcast_flag(exe_broadcast_flag),
        .exe_Request_alt_pc(request_alt_pc),
        .exe_Alt_PC(alt_addr),
        .exe_instr_num(0),

        .mem_complete_flag(0),
        .mem_broadcast_flag(0),
        .mem_instr_num(0),

        .rrat_map(),

        .Request_alt_pc_IF(),
        .Alt_PC_IF(),

        .head_instr_num(),

        .ROB_halt(),
        .rename_free(),
        .rename_free_reg(),

        .newMap_flag_rrat(),
        .reg2map_rrat(),
        .newMap_rrat(),

        .SYS(),
        .flush());



    //******************************************************************************
	EXE EXE(
    //******************************************************************************
    .IF_all_info(IF_all_info_EXE),
    .Request_Alt_PC(request_alt_pc),
    .alt_addr(alt_addr),
    .flush(flush),

    .issue_instr_num(instr_num_exe),

    // broadcast stuff
    .issue_RegWr_map(issue_RegWr_map),
    .issue_RegWr_flag(issue_RegWr_flag),
    .broadcast_flag(exe_broadcast_flag),
    .broadcast_map(exe_broadcast_map),
    .broadcast_reg(exe_broadcast_reg),
    .broadcast_val(exe_broadcast_val),

    // to mem stuff for broadcast
    .exe_instr_num(exe_instr_num),
    .exe_RegWr_map(exe_RegWr_map),
    .all_info_MEM(EXE_all_info_MEM),
    //******************************************************************************
    .CLK(CLK),
		.RESET(RESET),
		.Instr1_IN(Instr1_IDEXE),
		.Instr1_PC_IN(Instr1_PC_IDEXE),
		.OperandA1_IN(OperandA1_IDEXE),
		.OperandB1_IN(OperandB1_IDEXE),
		.WriteRegister1_IN(WriteRegister1_IDEXE),
		.MemWriteData1_IN(MemWriteData1_IDEXE),
		.RegWrite1_IN(RegWrite1_IDEXE),
		.ALU_Control1_IN(ALU_Control1_IDEXE),
		.MemRead1_IN(MemRead1_IDEXE),
		.MemWrite1_IN(MemWrite1_IDEXE),
		.ShiftAmount1_IN(ShiftAmount1_IDEXE),
		.Instr1_OUT(Instr1_EXEMEM),
		.Instr1_PC_OUT(Instr1_PC_EXEMEM),
		.ALU_result1_OUT(ALU_result1_EXEMEM),
		.WriteRegister1_OUT(WriteRegister1_EXEMEM),
		.MemWriteData1_OUT(MemWriteData1_EXEMEM),
		.RegWrite1_OUT(RegWrite1_EXEMEM),
		.ALU_Control1_OUT(ALU_Control1_EXEMEM),
		.MemRead1_OUT(MemRead1_EXEMEM),
		.MemWrite1_OUT(MemWrite1_EXEMEM));

    wire [31:0] data_write_2DC/*verilator public*/;
    wire [31:0] data_address_2DC/*verilator public*/;
    wire [1:0]  data_write_size_2DC/*verilator public*/;
    wire [31:0] data_read_fDC/*verilator public*/;
    wire        read_2DC/*verilator public*/;
    wire        write_2DC/*verilator public*/;
    //No caches, so:
    /* verilator lint_off UNUSED */
    wire        flush_2DC/*verilator public*/;
    /* verilator lint_on UNUSED */
    wire        data_valid_fDC /*verilator public*/;
    assign data_write_2DM = data_write_2DC;
    assign data_address_2DM = data_address_2DC;
    assign data_write_size_2DM = data_write_size_2DC;
    assign data_read_fDC = data_read_fDM;
    assign MemRead_2DM = read_2DC;
    assign MemWrite_2DM = write_2DC;
    assign data_valid_fDC = 1'b1;

    assign dBlkRead = 1'b0;
    assign dBlkWrite = 1'b0;
    assign block_write_2DM = block_read_fDM;
    /*verilator lint_off UNUSED*/
    wire unused_d1;
    wire unused_d2;
    /*verilator lint_on UNUSED*/
    assign unused_d1 = block_read_fDM_valid;
    assign unused_d2 = block_write_fDM_valid;

    wire [5:0] mem_broadcast_map;


    integer exe_instr_num;
    MEM MEM(
//******************************************************************************
        .EXE_all_info(EXE_all_info_MEM),
        .exe_RegWr_map(exe_RegWr_map),
        .exe_instr_num(exe_instr_num),

        .broadcast_map(mem_broadcast_map),
        .mem_instr_num(mem_instr_num),
//******************************************************************************
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_IN(Instr1_EXEMEM),
        .Instr1_PC_IN(Instr1_PC_EXEMEM),
        .ALU_result1_IN(ALU_result1_EXEMEM),
        .WriteRegister1_IN(WriteRegister1_EXEMEM),
        .MemWriteData1_IN(MemWriteData1_EXEMEM),
        .RegWrite1_IN(RegWrite1_EXEMEM),
        .ALU_Control1_IN(ALU_Control1_EXEMEM),
        .MemRead1_IN(MemRead1_EXEMEM),
        .MemWrite1_IN(MemWrite1_EXEMEM),
        .WriteRegister1_OUT(WriteRegister1_MEMWB),
        .RegWrite1_OUT(RegWrite1_MEMWB),
        .WriteData1_OUT(WriteData1_MEMWB),
        .data_write_2DM(data_write_2DC),
        .data_address_2DM(data_address_2DC),
        .data_write_size_2DM(data_write_size_2DC),
        .data_read_fDM(data_read_fDC),
        .MemRead_2DM(read_2DC),
        .MemWrite_2DM(write_2DC)
    );

/* verilator lint_on BLKSEQ */
endmodule
