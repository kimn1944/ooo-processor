`include "config.v"

`define LOG_PHYS    $clog2(NUM_PHYS_REGS)

module RegRead#(
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
  /*Register to write*/
  input [4:0] WriteReg1,
  /*Data to write*/
  input [31:0] WriteData1,
  /*Actually do it?*/
  input Write1,
  input [31:0] hi,
  input [31:0] lo);

	PhysRegFile  #(
	.NUM_PHYS_REGS(NUM_PHYS_REGS)
	)
  PhysRegFile (
      .CLK(CLK),
      .RESET(RESET),
      .RegA1(0),
      .RegB1(0),
      .RegC1(0),
      .DataA1(),
      .DataB1(),
      .DataC1(),
      .WriteReg1(WriteReg1),
      .WriteData1(WriteData1),
      .Write1(Write1),
      .hi(hi),
      .lo(lo));

    /* Write Me */

endmodule
