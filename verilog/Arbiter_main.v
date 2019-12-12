module Arbiter_main (
    input [15:0] ready,
    output reg [15:0] grant,
    output integer granted
);

wire GG0;
wire GG1;
wire GG2;
wire GG3;

wire GR0;
wire GR1;
wire GR2;
wire GR3;

always @(*) begin
    case(1)
        grant[0] : granted = 0;
        grant[1] : granted = 1;
        grant[2] : granted = 2;
        grant[3] : granted = 3;
        grant[4] : granted = 4;
        grant[5] : granted = 5;
        grant[6] : granted = 6;
        grant[7] : granted = 7;
        grant[8] : granted = 8;
        grant[9] : granted = 9;
        grant[10] : granted = 10;
        grant[11] : granted = 11;
        grant[12] : granted = 12;
        grant[13] : granted = 13;
        grant[14] : granted = 14;
        grant[15] : granted = 15;
        default : granted = 16;
    endcase
end
//assign granted = grant[0] ? 0 :(grant[1] ? 1 : (grant[2] ? 2 : (grant[3] ? 3: (grant[4] ? 4 : (grant[5]? 5: (grant[6] ? 6 : (grant[7] ? 7 : (grant[8] ? 8 : (grant[9] ? 9: (grant[10] ? 10 : (grant[11] ? 11: (grant[12] ? 12: (grant[13] ? 13 : (grant[14] ? 14 : (grant[15] ? 15: 16))))))))))))));

Arbiter Arbiter0(
    //child side
    .R0(ready[0]),
    .R1(ready[1]),
    .R2(ready[2]),
    .R3(ready[3]),

    .G0(grant[0]),
    .G1(grant[1]),
    .G2(grant[2]),
    .G3(grant[3]),    

    //parent side
    .GG(GG0), //group grant
    .GR(GR0) //group request
);

Arbiter Arbiter1(
    //child side
    .R0(ready[4]),
    .R1(ready[5]),
    .R2(ready[6]),
    .R3(ready[7]),

    .G0(grant[4]),
    .G1(grant[5]),
    .G2(grant[6]),
    .G3(grant[7]),    

    //parent side
    .GG(GG1), //group grant
    .GR(GR2) //group request
);

Arbiter Arbiter2(
    //child side
    .R0(ready[8]),
    .R1(ready[9]),
    .R2(ready[10]),
    .R3(ready[11]),

    .G0(grant[8]),
    .G1(grant[9]),
    .G2(grant[10]),
    .G3(grant[11]),    

    //parent side
    .GG(GG2), //group grant
    .GR(GR2) //group request
);

Arbiter Arbiter3(
    //child side
    .R0(ready[12]),
    .R1(ready[13]),
    .R2(ready[14]),
    .R3(ready[15]),

    .G0(grant[12]),
    .G1(grant[13]),
    .G2(grant[14]),
    .G3(grant[15]),    

    //parent side
    .GG(GG3), //group grant
    .GR(GR3) //group request
);


Arbiter parent0(
    //child side
    .R0(GR0),
    .R1(GR1),
    .R2(GR2),
    .R3(GR3),

    .G0(GG0),
    .G1(GG1),
    .G2(GG2),
    .G3(GG3),    

    //parent side
    .GG(1), //group grant
    .GR() //group request
);


endmodule