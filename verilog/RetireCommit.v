/**************************************
* Module: RetireCommit
* Date:2013-12-10  
* Author: isaac     
*
* Description: Handles commits to the ROB, and retires instructions from the ROB.
*
* This is the last stop of this train. All passengers must exit.
***************************************/
`define LOG_PHYS    $clog2(NUM_PHYS_REGS)
module  RetireCommit #(
    parameter NUM_PHYS_REGS = 64
    /* You may want more parameters here */
)
(
    /* Write Me */
);/*verilator public_module*/

RAT #(
    .NUM_ARCH_REGS(35),
    .NUM_PHYS_REGS(NUM_PHYS_REGS)
    /* Maybe Others? */
)RRAT(
    /* Write Me */
);

    /* Write Me */

endmodule

