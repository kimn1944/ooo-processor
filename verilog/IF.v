`include "config.v"
/**************************************
* Module: Fetch
* Date:2013-11-24  
* Author: isaac     
*
* Description: Master Instruction Fetch Module
***************************************/
module  IF
(
    input CLK,
    input RESET,
    
    //This should contain the fetched instruction
    output reg [31:0] Instr1_OUT,
    //This should contain the address of the fetched instruction [DEBUG purposes]
    output reg [31:0] Instr_PC_OUT,
    //This should contain the address of the instruction after the fetched instruction (used by ID)
    output reg [31:0] Instr_PC_Plus4,
    
`ifdef USE_ICACHE
    //This should be set to true if the instruction was successfully fetched and is valid.
    output Instr1_Available,
    
`endif
    //Will be set to true if we need to just freeze the fetch stage.
    input STALL,
    
    //There was probably a branch -- please load the alternate PC instead of Instr_PC_Plus4.
    input Request_Alt_PC,
    //Alternate PC to load
    input [31:0] Alt_PC,
    
    //Address from which we want to fetch an instruction
    output [31:0] Instr_address_2IM,
    //Instruction received from instruction memory
    input [31:0]   Instr1_fIM
`ifdef USE_ICACHE
    ,
    //Specifies that the instruction received was actually valid
    input Instr1_fIM_IsValid
`endif
);

    wire [31:0] IncrementAmount;
    assign IncrementAmount = 32'd4; //NB: This might get modified for superscalar.
    
`ifdef INCLUDE_IF_CONTENT
    assign Instr_address_2IM = (Request_Alt_PC)?Alt_PC:Instr_PC_Plus4;
`else
    assign Instr_address_2IM = Instr_PC_Plus4;  //Are you sure that this is correct?
`endif
    
`ifdef USE_ICACHE
    
    assign Instr1_Available = Instr1_fIM_IsValid;
    
`endif

always @(posedge CLK or negedge RESET) begin
    if(!RESET) begin
        Instr1_OUT <= 0;
        Instr_PC_OUT <= 0;
        Instr_PC_Plus4 <= 32'hBFC00000;
        $display("FETCH [RESET] Fetching @%x", Instr_PC_Plus4);
    end else if(CLK) begin
        if(!STALL) begin
`ifdef USE_ICACHE
            if(Instr1_fIM_IsValid) begin
`endif  //USE_ICACHE
                Instr1_OUT <= Instr1_fIM;
                Instr_PC_OUT <= Instr_address_2IM;
`ifdef INCLUDE_IF_CONTENT
                Instr_PC_Plus4 <= Instr_address_2IM + IncrementAmount;
                $display("FETCH:Instr@%x=%x;Next@%x",Instr_address_2IM,Instr1_fIM,Instr_address_2IM + IncrementAmount);
                $display("FETCH:ReqAlt[%d]=%x",Request_Alt_PC,Alt_PC);
`else
                /* You should probably assign something to Instr_PC_Plus4. */
                $display("FETCH:Instr@%x=%x;Next@%x",Instr_address_2IM,Instr1_fIM,Instr_address_2IM + IncrementAmount);
                $display("FETCH:ReqAlt[%d]=%x",Request_Alt_PC,Alt_PC);
`endif
`ifdef USE_ICACHE
            end else begin
                $display("FETCH:Instr not valid");
            end
`endif  //USE_ICACHE
        end else begin
            $display("FETCH: Stalling; next request will be %x",Instr_address_2IM);
        end
    end
end

endmodule

