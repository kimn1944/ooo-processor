`include "config.v"
//-----------------------------------------
//            Pipelined MIPS
//-----------------------------------------
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
    wire [31:0] Instr_PC_Plus4_IFID;
`ifdef USE_ICACHE
    wire        Instr1_Available_IFID;
`endif
    wire        STALL_IDIF;
    wire        Request_Alt_PC_IDIF;
    wire [31:0] Alt_PC_IDIF;
    
    
//Connecting wires between IC and IF
    wire [31:0] Instr_address_2IC/*verilator public*/;
    //Instr_address_2IC is verilator public so that sim_main can give accurate 
    //displays.
    //We could use Instr_address_2IM, but this way sim_main doesn't have to 
    //worry about whether or not a cache is present.
    wire [31:0] Instr1_fIC;
`ifdef USE_ICACHE
    wire        Instr1_fIC_IsValid;
`endif
    wire [31:0] Instr2_fIC;
`ifdef USE_ICACHE
    wire        Instr2_fIC_IsValid;
    Cache #(
    .CACHENAME("I$1")
    ) ICache(
        .CLK(CLK),
        .RESET(RESET),
        .Read1(1'b1),
        .Write1(1'b0),
        .Flush1(1'b0),
        .Address1(Instr_address_2IC),
        .WriteData1(32'd0),
        .WriteSize1(2'd0),
        .ReadData1(Instr1_fIC),
        .OperationAccepted1(Instr1_fIC_IsValid),
`ifdef SUPERSCALAR
        .ReadData2(Instr2_fIC),
        .DataValid2(Instr2_fIC_IsValid),
`endif
        .read_2DM(iBlkRead),
/* verilator lint_off PINCONNECTEMPTY */
        .write_2DM(),
/* verilator lint_on PINCONNECTEMPTY */
        .address_2DM(Instr_address_2IM),
/* verilator lint_off PINCONNECTEMPTY */
        .data_2DM(),
/* verilator lint_on PINCONNECTEMPTY */
        .data_fDM(block_read_fIM),
        .dm_operation_accepted(block_read_fIM_valid)
    );
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i1;
    wire [31:0] unused_i2;
    /*verilator lint_on UNUSED*/
    assign unused_i1 = Instr1_fIM;
    assign unused_i2 = Instr2_fIM;
`ifdef SUPERSCALAR
`else
    assign Instr2_fIC = 32'd0;
    assign Instr2_fIC_IsValid = 1'b0;
`endif
`else
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
`endif
`ifdef SUPERSCALAR
`else
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i3;
`ifdef USE_ICACHE
    wire unused_i4;
`endif
    /*verilator lint_on UNUSED*/
    assign unused_i3 = Instr2_fIC;
`ifdef USE_ICACHE
    assign unused_i4 = Instr2_fIC_IsValid;
`endif
`endif

    IF IF(
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_OUT(Instr1_IFID),
        .Instr_PC_OUT(Instr_PC_IFID),
        .Instr_PC_Plus4(Instr_PC_Plus4_IFID),
`ifdef USE_ICACHE
        .Instr1_Available(Instr1_Available_IFID),
`endif
        .STALL(STALL_IDIF),
        .Request_Alt_PC(Request_Alt_PC_IDIF),
        .Alt_PC(Alt_PC_IDIF),
        .Instr_address_2IM(Instr_address_2IC),
        .Instr1_fIM(Instr1_fIC)
`ifdef USE_ICACHE
        ,
        .Instr1_fIM_IsValid(Instr1_fIC_IsValid)
`endif
    );
    
`ifdef USE_DCACHE
	wire        STALL_fMEM;
`endif

    wire [4:0]  WriteRegister1_MEMWB;
	wire [31:0] WriteData1_MEMWB;
	wire        RegWrite1_MEMWB;
	
	wire [31:0] Instr1_IDEXE;
    wire [31:0] Instr1_PC_IDEXE;
	wire [31:0] OperandA1_IDEXE;
	wire [31:0] OperandB1_IDEXE;
`ifdef HAS_FORWARDING
    wire [4:0]  RegisterA1_IDEXE;
    wire [4:0]  RegisterB1_IDEXE;
`endif
    wire [4:0]  WriteRegister1_IDEXE;
    wire [31:0] MemWriteData1_IDEXE;
    wire        RegWrite1_IDEXE;
    wire [5:0]  ALU_Control1_IDEXE;
    wire        MemRead1_IDEXE;
    wire        MemWrite1_IDEXE;
    wire [4:0]  ShiftAmount1_IDEXE;
    
`ifdef HAS_FORWARDING
    wire [4:0]  BypassReg1_EXEID;
    wire [31:0] BypassData1_EXEID;
    wire        BypassValid1_EXEID;
    
    wire [4:0]  BypassReg1_MEMID;
    wire [31:0] BypassData1_MEMID;
    wire        BypassValid1_MEMID;
`endif
    
	
	ID ID(
		.CLK(CLK),
		.RESET(RESET),
`ifdef USE_DCACHE
		.STALL_fMEM(STALL_fMEM),
`endif
		.Instr1_IN(Instr1_IFID),
`ifdef USE_ICACHE
		.Instr1_Valid_IN(Instr1_Available_IFID),
`endif
		.Instr_PC_IN(Instr_PC_IFID),
		.Instr_PC_Plus4_IN(Instr_PC_Plus4_IFID),
		.WriteRegister1_IN(WriteRegister1_MEMWB),
		.WriteData1_IN(WriteData1_MEMWB),
		.RegWrite1_IN(RegWrite1_MEMWB),
		.Alt_PC(Alt_PC_IDIF),
		.Request_Alt_PC(Request_Alt_PC_IDIF),
		.Instr1_OUT(Instr1_IDEXE),
        .Instr1_PC_OUT(Instr1_PC_IDEXE),
		.OperandA1_OUT(OperandA1_IDEXE),
		.OperandB1_OUT(OperandB1_IDEXE),
`ifdef HAS_FORWARDING
		.ReadRegisterA1_OUT(RegisterA1_IDEXE),
		.ReadRegisterB1_OUT(RegisterB1_IDEXE),
`else
/* verilator lint_off PINCONNECTEMPTY */
        .ReadRegisterA1_OUT(),
        .ReadRegisterB1_OUT(),
/* verilator lint_on PINCONNECTEMPTY */
`endif
		.WriteRegister1_OUT(WriteRegister1_IDEXE),
		.MemWriteData1_OUT(MemWriteData1_IDEXE),
		.RegWrite1_OUT(RegWrite1_IDEXE),
		.ALU_Control1_OUT(ALU_Control1_IDEXE),
		.MemRead1_OUT(MemRead1_IDEXE),
		.MemWrite1_OUT(MemWrite1_IDEXE),
		.ShiftAmount1_OUT(ShiftAmount1_IDEXE),
`ifdef HAS_FORWARDING
		.BypassReg1_EXEID(BypassReg1_EXEID),
		.BypassData1_EXEID(BypassData1_EXEID),
		.BypassValid1_EXEID(BypassValid1_EXEID),
		.BypassReg1_MEMID(BypassReg1_MEMID),
		.BypassData1_MEMID(BypassData1_MEMID),
		.BypassValid1_MEMID(BypassValid1_MEMID),
`endif
		.SYS(SYS),
		.WANT_FREEZE(STALL_IDIF)
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
`ifdef HAS_FORWARDING
    wire [31:0] ALU_result_async1;
    wire        ALU_result_async_valid1;
`endif
	
	EXE EXE(
		.CLK(CLK),
		.RESET(RESET),
`ifdef USE_DCACHE
		.STALL_fMEM(STALL_fMEM),
`endif
		.Instr1_IN(Instr1_IDEXE),
		.Instr1_PC_IN(Instr1_PC_IDEXE),
`ifdef HAS_FORWARDING
		.RegisterA1_IN(RegisterA1_IDEXE),
`endif
		.OperandA1_IN(OperandA1_IDEXE),
`ifdef HAS_FORWARDING
		.RegisterB1_IN(RegisterB1_IDEXE),
`endif
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
		.MemWrite1_OUT(MemWrite1_EXEMEM)
`ifdef HAS_FORWARDING
		,
		.BypassReg1_MEMEXE(WriteRegister1_MEMWB),
		.BypassData1_MEMEXE(WriteData1_MEMWB),
		.BypassValid1_MEMEXE(RegWrite1_MEMWB),
		.ALU_result_async1(ALU_result_async1),
		.ALU_result_async_valid1(ALU_result_async_valid1)
`endif
	);
	
`ifdef HAS_FORWARDING
    assign BypassReg1_EXEID = WriteRegister1_IDEXE;
    assign BypassData1_EXEID = ALU_result_async1;
    assign BypassValid1_EXEID = ALU_result_async_valid1;
`endif
     
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
`ifdef USE_DCACHE
    Cache #(
    .CACHENAME("D$1")
    ) DCache(
        .CLK(CLK),
        .RESET(RESET),
        .Read1(read_2DC),
        .Write1(write_2DC),
        .Flush1(flush_2DC),
        .Address1(data_address_2DC),
        .WriteData1(data_write_2DC),
        .WriteSize1(data_write_size_2DC),
        .ReadData1(data_read_fDC),
        .OperationAccepted1(data_valid_fDC),
`ifdef SUPERSCALAR
/* verilator lint_off PINCONNECTEMPTY */
        .ReadData2(),
        .DataValid2(),
/* verilator lint_on PINCONNECTEMPTY */
`endif
        .read_2DM(dBlkRead),
        .write_2DM(dBlkWrite),
        .address_2DM(data_address_2DM),
        .data_2DM(block_write_2DM),
        .data_fDM(block_read_fDM),
        .dm_operation_accepted((dBlkRead & block_read_fDM_valid) | (dBlkWrite & block_write_fDM_valid))
    );
    assign MemRead_2DM = 1'b0;
    assign MemWrite_2DM = 1'b0;
    assign data_write_2DM = 32'd0;
    assign data_write_size_2DM = 2'b0;
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_d1;
    /*verilator lint_on UNUSED*/
    assign unused_d1 = data_read_fDM;
`else
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
`endif
     
    MEM MEM(
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
`ifdef USE_DCACHE
        ,
        .MemFlush_2DM(flush_2DC),
        .data_valid_fDM(data_valid_fDC),
        .Mem_Needs_Stall(STALL_fMEM)
`endif
`ifdef HAS_FORWARDING
        ,
        .WriteData1_async(BypassData1_MEMID)
`endif
    );
     
`ifdef HAS_FORWARDING
    assign BypassReg1_MEMID = WriteRegister1_EXEMEM;
`ifdef USE_DCACHE
    assign BypassValid1_MEMID = RegWrite1_EXEMEM && !STALL_fMEM;
`else
    assign BypassValid1_MEMID = RegWrite1_EXEMEM;
`endif
`endif
    
`ifdef OUT_OF_ORDER
    RegRead RegRead(
    );
    RetireCommit RetireCommit(
    );
`endif
endmodule
