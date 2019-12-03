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
    
    //Will be set to true if we need to just freeze the fetch stage.
    input STALL,
    
    //There was probably a branch -- please load the alternate PC instead of Instr_PC_Plus4.
    input Request_Alt_PC,
    //Alternate PC to load
    input [31:0] Alt_PC,
    
    //Address from which we want to fetch an instruction
    output [31:0] Instr_address_2IM,
    //Instruction received from instruction memory
    input [31:0]   Instr1_fIM,

    //***********************************************************************************************
    input reg stall_C
	//***********************************************************************************************
	
);

	//integer ring_size = 3;
	
    wire [31:0] IncrementAmount;
    assign IncrementAmount = 32'd4; //NB: This might get modified for superscalar.    

`ifdef INCLUDE_IF_CONTENT
    assign Instr_address_2IM = (Request_Alt_PC)?Alt_PC:Instr_PC_Plus4;
`else
    assign Instr_address_2IM = Instr_PC_Plus4;  //Are you sure that this is correct?
`endif
    
	//************************************************
    //reg [1:0] Instr_ring;
	//***********************************************

always @(posedge CLK or negedge RESET) begin
    if(!RESET) begin
        Instr1_OUT <= 0;
        Instr_PC_OUT <= 0;
        Instr_PC_Plus4 <= 32'hBFC00000;
//************************************************
        //Instr_ring <= 2'b01;
//***********************************************
        $display("FETCH [RESET] Fetching @%x", Instr_PC_Plus4);
    end else if(CLK) begin
        if(!STALL & !stall_C) begin
            Instr1_OUT <= Instr1_fIM;
            Instr_PC_OUT <= Instr_address_2IM;
//***********************************************
			//Instr_ring <= {{Instr_ring[0]}, {Instr_ring[1]}};
//***********************************************
`ifdef INCLUDE_IF_CONTENT
            Instr_PC_Plus4 <= Instr_address_2IM + IncrementAmount;
            $display("FETCH:Instr@%x=%x;Next@%x",Instr_address_2IM,Instr1_fIM,Instr_address_2IM + IncrementAmount);
            $display("FETCH:ReqAlt[%d]=%x",Request_Alt_PC,Alt_PC);
`else
            /* You should probably assign something to Instr_PC_Plus4. */
            $display("FETCH:Instr@%x=%x;Next@%x",Instr_address_2IM,Instr1_fIM,Instr_address_2IM + IncrementAmount);
            $display("FETCH:ReqAlt[%d]=%x",Request_Alt_PC,Alt_PC);
`endif
        end else begin
			//if (stall_IC)begin
//***********************************************
				//Instr_ring <= {{Instr_ring[0]}, {Instr_ring[1]}};
//***********************************************
			//end
            $display("FETCH: Stalling; next request will be %x",Instr_address_2IM);
        end
    end
end

endmodule

