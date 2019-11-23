//-----------------------------------------
//           RAT
//-----------------------------------------

`define LOG_ARCH    $clog2(NUM_ARCH_REGS)
`define LOG_PHYS    $clog2(NUM_PHYS_REGS)

module RAT #(
	/* 
	 * NUM_ARCH_REGS is the number of architectural registers present in the 
	 * RAT. 
	 *
	 * sim_main assumes that the value of LO is stored in architectural 
	 * register 33, and that the value of HI is stored in architectural 
	 * register 34.
	 *
	 * It is left as an exercise to the student to explain why.
	 */
    parameter NUM_ARCH_REGS = 35,
    parameter NUM_PHYS_REGS = 64
    /* Maybe Others? */
)
(	
    /* Write Me */
		); 

	// actual RAT memory
	reg [`LOG_PHYS-1:0] regPtrs [NUM_ARCH_REGS-1:0] /*verilator public_flat*/;

    /* Write Me */


endmodule

