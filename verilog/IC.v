/*
File: CACHE.v
Author: Nikita Kim
Email: kimn1944@gmail.com
Date: 11/8/19
*/

`include "config.v"

module IC
    #()
    (input clk,
    input reset,
    input stall,

    // reading or writing
    input [31:0] data_addr,

    input [31:0] requested_data,
    output reg [31:0] request_addr,

    // general outputs
    output reg stop,
    output reg [31:0] data);
    // end arguments

    integer i;
    reg [273:0]  cache [1023:0];

    // accessing info in the cache
    wire [9:0]  idx;
    wire [16:0] tag;
    wire [2:0] ofst;
    assign idx  = data_addr[14:5];
    assign tag  = data_addr[31:15];
    assign ofst = data_addr[4:2];

    wire [16:0] cache_tag;
    wire [31:0] cache_data;
    wire cache_valid;
    integer cache_ofst    = 32 * ofst;
    assign cache_tag      = cache[idx][272:256];
    assign cache_data     = cache[idx][cache_ofst +:32];
    assign cache_valid    = cache[idx][273] & (tag == cache_tag);
    // end accessing info in the cache

    // dealing with miss
    reg [8:0] ring;
    reg [2:0] switch;

    always @(negedge cache_valid) begin
        if(!stall) begin
            ring    <= 9'b100000000;
            switch  <= 0;
        end
    end

    always @(posedge clk) begin
        if(!stall & stop) begin
            switch                <= switch + 1;
            ring                  <= {1'b1, ring[8:1]};
            cache[idx][272:256]   <= tag;
            cache[idx][(switch) * 32 +:32]  <= requested_data;
            cache[idx][273] <= 1;
        end
    end
    // end dealing with miss

    always @ * begin
        if(!stall) begin
            request_addr = {tag, idx, switch, 2'b00};
            stop <= ~ring[0];
            data <= cache_data;
        end
    end

    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            for(i = 0; i < 1024; i = i + 1) begin
                cache[273] = 0;
            end
        end
        `ifdef IC_PRINT
            $display("\t\t\t\tIC Output");
            $display("Data Addr: %x, Data: %x", data_addr, data);
            $display("Req Addr: %x, Req Data: %x", request_addr, requested_data);
            $display("Stop: %x", stop);
            $display("Idx: %x, Tag: %x, Ofst: %x", idx, tag, ofst);
            $display("Cache Val: %x, Cache Data: %x, Cache Tag: %x, Cache Ofst: %d", cache_valid, cache_data, cache_tag, cache_ofst);
            $display("Switch: %d, Ring: %b, Addr: %b", (switch - 1) * 32, ring, data_addr);
            $display("Cache: %x", cache[idx]);
            $display("\t\t\t\tIC End");
        `endif
    end

endmodule
