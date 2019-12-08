module Issue (
    input CLK,
    input RESET,
    input STALL,
    input FLUSH,  

);

reg [15:0] ready;
reg [15:0] grant;
wire GG0;
wire GG1;
wire GG2;
wire GG3;
wire GR0;
wire GR1;
wire GR2;
wire GR3;

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
    .GR(GR0), //group request
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
    .GR(GR2), //group request
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
    .GR(GR2), //group request
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
    .GR(GR3), //group request
);

Arbiter Arbiter_main(
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
    .GG(), //group grant
    .GR(), //group request
);

endmodule