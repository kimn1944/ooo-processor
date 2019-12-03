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
    wire [31:0] Instr2_fIC;
    //assign Instr_address_2IM = Instr_address_2IC;
    //assign Instr1_fIC = Instr1_fIM;
    //assign Instr2_fIC = Instr2_fIM;
    assign iBlkRead = 1'b0;
    /*verilator lint_off UNUSED*/
    wire [255:0] unused_i1;
    wire unused_i2;
    /*verilator lint_on UNUSED*/
    assign unused_i1 = block_read_fIM;
    assign unused_i2 = block_read_fIM_valid;
`ifdef SUPERSCALAR
`else
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i3;
    /*verilator lint_on UNUSED*/
    assign unused_i3 = Instr2_fIC;
`endif


    IC #() IC
        (.clk(CLK),
        .reset(RESET),
        .stall(STALL_IDIF),
        .data_addr(Instr_address_2IC),
        .requested_data(Instr1_fIM),
        .request_addr(Instr_address_2IM),
        .stop(stall_IC),
        .data(Instr1_fIC));


    IF IF(
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_OUT(Instr1_IFID),
        .Instr_PC_OUT(Instr_PC_IFID),
        .Instr_PC_Plus4(Instr_PC_Plus4_IFID),
        .STALL(STALL_IDIF),
        .Request_Alt_PC(Request_Alt_PC_IDIF),
        .Alt_PC(Alt_PC_IDIF),
        .Instr_address_2IM(Instr_address_2IC),
        .Instr1_fIM(Instr1_fIC),
//*********************************************
        .stall_C(stall_C)
//*********************************************
    );
    
//*********************************************
	wire stall_IC;
//*********************************************
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
		.Instr1_IN(Instr1_IFID),
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
//*********************************************
		.stall_IC(stall_C),
		.sys_EXE(sys_EXE),
//*********************************************
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
		.MemWrite1_OUT(MemWrite1_EXEMEM),
//*********************************************
		.stall_IC(stall_C),
		.sys_EXE(sys_EXE),
		.sys_DC(sys_DC)
//*********************************************
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
    assign data_write_2DM = data_write_2DC;
    assign data_address_2DM = data_address_2DC;
    assign data_write_size_2DM = data_write_size_2DC;
    assign data_read_fDC = data_read_fDM;
    assign MemRead_2DM = read_2DC;
    assign MemWrite_2DM = write_2DC;
    assign data_valid_fDC = 1'b1;
     
    assign dBlkRead = 1'b0;
    //assign dBlkWrite = 1'b0;
    //assign block_write_2DM = block_read_fDM;
    /*verilator lint_off UNUSED*/
    wire unused_d1;
    wire unused_d2;
    /*verilator lint_on UNUSED*/
    assign unused_d1 = block_read_fDM_valid;
    assign unused_d2 = block_write_fDM_valid;
     
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
        .data_write_2DM(MEM_wr_data),//(data_write_2DC),
        .data_address_2DM(MEM_addr),//(data_address_2DC),
        .data_write_size_2DM(MEM_wr_size),//(data_write_size_2DC),
        .data_read_fDM(MEM_rd_data),//(data_read_fDC),
        .MemRead_2DM(MEM_rd_req),//(read_2DC),
        .MemWrite_2DM(MEM_wr_req),//(write_2DC),
//*********************************************
		.stall_IC(stall_C)
//*********************************************
`ifdef HAS_FORWARDING
        , 
        .WriteData1_async(BypassData1_MEMID)
`endif
    );
always @ (posedge CLK) begin
	$display("\n\n ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
	$display("MEM:Instr1_OUT=%x,Instr1_PC_OUT=%x",Instr1_EXEMEM,Instr1_PC_EXEMEM);
	$display("MEM:data_address_2DM=%x; data_write_2DM(%d)=%x(%d); data_read_fDM(%d)=%x\n",MEM_addr,MEM_wr_req,MEM_wr_data,data_write_size_2DC,MEM_rd_req,MEM_rd_data);		
	$display("DCache(MEM): data_address: %x; data_req: %x; wren: %x; MEM_wr_data(%d): %x", MEM_addr, MEM_data_req, MEM_wr_req, MEM_wr_size, MEM_wr_data);
	$display("DCache(MEM): MEM_rd_data: %x; hit_DC: %x; Stall_DC: %x", MEM_rd_data, hit_DC, stall_DC);
	$display("DCache(DRAM wr): DRAM_wr(%d): %x at %x; wr_valid: %d", write_2DC, data_write_2DC, DRAM_wr_addr, DRAM_wr_valid);
	$display("DCache(DRAM rd): DRAM_rd(%d): %x at %x; rd_valid: %d", read_2DC, data_read_fDC, DRAM_rd_addr, DRAM_rd_valid);
	$display("DCache(DRAM): DRAM_addr_2DC(%d): %x", dBlkWrite, data_address_2DC);

	$display("Cache_block: valid/dirty (1,2): %b %b; tag: %x(1) %x(2) %x(MEM); lru: %d", v_dirty1, v_dirty2, tag1, tag2, tag_MEM, lru);
	$display("Cache_block1: Block[0]: %x  Block[1]: %x ", Cache_block1[0:31], Cache_block1[32:63]);
	$display("Cache_block1: Block[2]: %x  Block[3]: %x ", Cache_block1[64:95], Cache_block1[96:127]);
	$display("Cache_block1: Block[6]: %x  Block[7]: %x ", Cache_block1[128:159], Cache_block1[160:191]);
	$display("Cache_block1: Block[6]: %x  Block[7]: %x ", Cache_block1[192:223], Cache_block1[224:255]);
	$display("");
	$display("Cache_block1: Block[0]: %x  Block[1]: %x ", Cache_block2[0:31], Cache_block2[32:63]);
	$display("Cache_block1: Block[2]: %x  Block[3]: %x ", Cache_block2[64:95], Cache_block2[96:127]);
	$display("Cache_block1: Block[4]: %x  Block[5]: %x ", Cache_block2[128:159], Cache_block2[160:191]);
	$display("Cache_block1: Block[6]: %x  Block[7]: %x ", Cache_block2[192:223], Cache_block2[224:255]);
	$display("DCache(DRAM): dBlkWrite(%d , %d, %d): %x", dBlkWrite, j, k, block_write_2DM);

	$display("\n vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv");
end

wire stall_C = stall_DC | stall_IC;
//wire FLUSH;

wire DRAM_wr_req;
wire [31:0] DRAM_wr_addr;
wire [31:0] DRAM_wr_data;
wire DRAM_wr_valid;

wire DRAM_rd_req;
wire [31:0] DRAM_rd_addr;
wire [31:0] DRAM_rd_data;
wire DRAM_rd_valid;

wire [31:0] MEM_addr;
wire MEM_data_req;
wire [31:0] MEM_rd_data;
wire [31:0] MEM_wr_data;
wire [1:0] MEM_wr_size;
wire hit_DC;
wire stall_DC;
wire [31:0] Cache_block [0:7];
wire MEM_rd_req;
wire MEM_wr_req;

wire sys_EXE;
wire sys_DC;
wire [10:0] j;
wire [10:0] k;
//assign FLUSH = 1'b0;
assign DRAM_wr_valid = 1'b1;
assign DRAM_rd_valid = 1'b1;
assign MEM_data_req = MEM_wr_req | MEM_rd_req;// read_2DC;
assign data_address_2DC = (dBlkWrite) ? DRAM_wr_addr:(read_2DC ? DRAM_rd_addr : 32'b0);
assign data_write_size_2DC = 2'b0;

	wire		  [0:255] Cache_block1;
	wire		  [0:255] Cache_block2;
	wire			[0:1]	 v_dirty1;
    wire            [0:1]   v_dirty2;
	wire			[17:0]	 tag1;
	wire			[17:0]	 tag2;
	wire			[17:0]	 tag_MEM;
	wire				 lru;

D_Cache D_Cache(
    .CLK(CLK),
    .RESET(RESET),
    //.FLUSH(FLUSH),
    // DRAM write     
    .DRAM_wr_req(write_2DC),// request writing data to DRAM
    .DRAM_wr_addr(DRAM_wr_addr),// write data address
    .DRAM_wr_data(data_write_2DC),//(DRAM_wr_data),// write data
    .DRAM_wr_valid(DRAM_wr_valid),// write a word valid
    // DRAM read
	.DRAM_rd_req(read_2DC),
    .DRAM_rd_addr(DRAM_rd_addr),// address to read data from
    .DRAM_rd_data(data_read_fDC),// data read from DRAM
    .DRAM_rd_valid(DRAM_rd_valid),// valid data achieved from DRAM
    // MEM
	.instruction(Instr1_EXEMEM),
    .MEM_addr(MEM_addr),//(data_address_2DC),// address to Read or write to cache
    .MEM_data_req(MEM_data_req),// data request
    .wren (MEM_wr_req),// write/read
    .MEM_wr_data (MEM_wr_data),// write data coming from MEM to DRAM
	.MEM_wr_size(MEM_wr_size),
    .MEM_rd_data(MEM_rd_data),// data read and send to MEM

    .hit(hit_DC),// cache hit or miss
    .stall_DC(stall_DC),// if miss, stall until data is get from DRAM
	
	.D_SRAM_block(Cache_block),
	.D_SRAM_blockk1(Cache_block1),
	.D_SRAM_blockk2(Cache_block2),


	.v_dirty1(v_dirty1),
    .v_dirty2(v_dirty2),
	.tag1_DM(tag1),
	.tag2_DM(tag2),
	.lru_DM(lru),
	.tag_MEMM(tag_MEM),

	.dBlkwrite(dBlkWrite),
	.block_write_2DM(block_write_2DM),
	.sys_DC(sys_DC),
	.j(j),
	.k(k)
);

// module    D_Cache(     
//     input                CLK,    
//     input                RESET,
//     input                FLUSH,
    
//     output               DRAM_wr_req,    
//     output        [31:0] DRAM_wr_addr,   
//     output reg    [31:0] DRAM_wr_data,   
//     input                DRAM_wr_valid,  
        
//     output               DRAM_rd_req,    
//     output        [31:0] DRAM_rd_addr,   
//     input         [31:0] DRAM_rd_data,   
//     input                DRAM_rd_valid,  
         
//     input         [31:0] MEM_addr,       
//     input                MEM_data_req,   
//     input                wren,           
//     input         [31:0] MEM_wr_data,    

//     output        [31:0] MEM_rd_data,    
//     output               hit,            
//     output               stall_DC        
// );
     
`ifdef HAS_FORWARDING
    assign BypassReg1_MEMID = WriteRegister1_EXEMEM;
    assign BypassValid1_MEMID = RegWrite1_EXEMEM;
`endif
    
endmodule
