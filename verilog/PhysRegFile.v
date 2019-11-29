`include "config.v"


`define LOG_PHYS    $clog2(NUM_PHYS_REGS)

module PhysRegFile #(
    parameter NUM_PHYS_REGS = 64
)
(
    input CLK,
    input RESET,
    /*Register A to read*/
    input [4:0] RegA1,
    /*Register B to read*/
    input [4:0] RegB1,
    /*Register C to read*/
    input [4:0] RegC1,
    /*Value of register A*/
    output [31:0] DataA1,
    /*Value of register B*/
    output [31:0] DataB1,
    /*Value of register C*/
    output [31:0] DataC1,
    /*Register to write*/
    input [4:0] WriteReg1,
    /*Data to write*/
    input [31:0] WriteData1,
    /*Actually do it?*/
    input Write1,
    input [31:0] hi,
    input [31:0] lo);

	  reg [31:0] PReg [NUM_PHYS_REGS-1:0] /*verilator public*/;

integer i;
always @(posedge CLK or negedge RESET) begin
  	if (!RESET) begin
        for(i = 0; i < NUM_PHYS_REGS; i = i + 1) begin
            PReg[i] = 0;
        end
    end else begin
        PReg[33] <= lo;
        PReg[34] <= hi;
`ifdef HAS_WRITEBACK
        if (Write1) begin
            PReg[{1'b0, WriteReg1}] <= WriteData1;
            $display("IDWB:PReg[%d]=%x",WriteReg1,WriteData1);
            $display("WriteReg1: %b, WriteData1: %x, Write1: %b", {1'b0, WriteReg1}, WriteData1, Write1);
        end
`else
        /*You might want to process the writebacks*/
        $display("IDWB:%d?PReg[%d]=%x",Write1,WriteReg1,WriteData1);
`endif
    end
end
endmodule
