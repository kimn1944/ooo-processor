module Arbiter (
    //child side
    input R0,
    input R1,
    input R2,
    input R3,

    output reg G0,
    output reg G1,
    output reg G2,
    output reg G3,    

    //parent side
    input GG, //group grant
    output reg GR //group request
);

initial begin
    G0 <= 0; 
    G1 <= 0; 
    G2 <= 0; 
    G3 <= 0; 
    GR <= 0; 
end

assign GR = R0 or R1 or R2 or R3;
assign G0 = GG and R0;
assign G1 = GG and !R0 and R1;
assign G2 = GG and !R0 and !R1 and R2;
assign G3 = GG and !R0 and !R1 and !R2 and R3;

endmodule