`include "config.v"
/**************************************
* Module: Cache
* Date:2013-11-09  
* Author: isaac     
*
* Description: 2-way set associative cache
* 32KB:
    32B/line (8 words)
    2lines/set = 64B/set
    32KB/64B=512sets
    2lines/set*512sets=1024lines
    
32-byte addresses:
    5 bits: byte within line
    18 bits: tag
    9 bits: index
    
33222222222211111111110000000000
10987654321098765432109876543210
TTTTTTTTTTTTTTTTTTIIIIIIIIIBBBBB


Line format (Hex):
000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f

***************************************/
`define INDEXBITS       $clog2(SETS)
`define LINEBITS        (LINEWORDS*WORDBITS)
`define LINEBYTES       (`LINEBITS/8)
`define BYTEBITS        $clog2(`LINEBYTES)
`define TAGBITS         (ADDRESSBITS-(`INDEXBITS+`BYTEBITS))
`define WAYBITS         $clog2(WAYS)
`define LINECOUNT       (WAYS*SETS)
`define LINECOUNTBITS   $clog2(`LINECOUNT)
`define LINEWORDBITS    $clog2(LINEWORDS)
`define WORDBITSBITS    (`BYTEBITS-$clog2(WORDBITS/8))
module  Cache
    #(
    parameter WAYS = 2,
    parameter SETS = 512,
    //parameter LINEBYTES = 32,
    parameter LINEWORDS = 8,
    parameter ADDRESSBITS = 32,
    parameter WORDBITS = 32,
    parameter CACHENAME = "$D1"
    )
    (
    input CLK,
    input RESET,

    input Read1, //Read Negedge
    input Write1,    //Read Negedge
    input Flush1,    //Read Negedge
    input[ADDRESSBITS-1:0]Address1,  //Read Negedge
    input[WORDBITS-1:0]WriteData1,    //Read Negedge
    input[1:0]WriteSize1,    //0==4;1==1;2==2;3==3   //Read Negedge
    output reg[WORDBITS-1:0]ReadData1,    //Write Negedge
    output reg OperationAccepted1,   //Write Negedge
`ifdef SUPERSCALAR
    output reg[WORDBITS-1:0]ReadData2,
    output reg DataValid2,
`endif

    output reg read_2DM,    //Write Posedge
    output reg write_2DM,   //Write Posedge
    output reg[ADDRESSBITS-1:0] address_2DM,    //Write Posedge
    output reg [`LINEBITS-1:0]data_2DM,   //Write Posedge
    input[`LINEBITS-1:0]data_fDM, //Read Posedge
    input dm_operation_accepted //Read Posedge

    );

//Index bits = $clog2(SETS)
//Byte bits = $clog2(LINEBYTES)
//Tag bits = (32-($clog2(SETS) + $clog2(LINEBYTES)))

reg[`WAYBITS:0] set_line_i;
reg set_found;
reg need_writeback;
reg need_readin;
reg [`LINEBITS-1:0]                                 temp_data;
reg [`LINEBITS-1:0]                                 temp_data_mask;
reg [ADDRESSBITS-1:0]                                       temp_address;


reg [`INDEXBITS-1:0]                                        requested_index;
reg [`INDEXBITS+`WAYBITS-1:0]                               requested_line;
reg [`TAGBITS-1:0]                                          requested_tag;
reg [`BYTEBITS-1:0]                                         requested_byte;
reg [`LINEWORDBITS-1:0]                                       requested_word;

reg [`LINEBITS-1:0]                                         lines           [0:`LINECOUNT-1];
reg [`TAGBITS-1:0]                                          tags            [0:(WAYS * SETS) - 1];
reg [`WAYBITS-1:0]                                          last_used_line  [0:`LINECOUNT-1];  //Avoid replacing most-recently-used
reg                                                         line_is_dirty   [0:`LINECOUNT-1];
reg                                                         line_is_valid   [0:`LINECOUNT-1];

reg                                                         line_incoming   [0:`LINECOUNT-1];  //Line is being populated; might not be ready yet.
reg [`LINECOUNTBITS-1:0]                             incoming_line;
reg [`LINEWORDBITS-1:0] line_fetch_counter;
reg [`LINECOUNTBITS:0] line_i;

reg [WORDBITS-1:0] tWriteData1;
reg [WORDBITS-1:0] WriteBits1;

reg in_flush;
reg [`LINECOUNTBITS:0] flush_position;

reg readin_no_wait;

reg got_readin;

    /*verilator lint_off BLKSEQ*/

always @(WriteData1 or WriteSize1) begin
    if(WORDBITS == 32) begin
    case(WriteSize1)
        0: begin WriteBits1=32'hFFFFFFFF; tWriteData1[WORDBITS-1:0]=WriteData1; end
        1: begin WriteBits1={{WORDBITS-32{1'b1}},32'hFF000000}; tWriteData1[31:24]=WriteData1[7:0]; end
        2: begin WriteBits1={{WORDBITS-32{1'b1}},32'hFFFF0000}; tWriteData1[31:16]=WriteData1[15:0]; end
        3: begin WriteBits1={{WORDBITS-32{1'b1}},32'hFFFFFF00}; tWriteData1[31:8]=WriteData1[23:0]; end
    endcase
    end else begin
        WriteBits1={WORDBITS{1'b1}};
        tWriteData1=WriteData1;
    end
end

always @(posedge CLK or negedge CLK or negedge RESET) begin
    //$display("CACHE%s:CLK=%d,RESET=%d,Accepted=%d",CACHENAME,CLK,RESET,OperationAccepted1);
    if(!RESET) begin
        ReadData1 <= {WORDBITS{1'b0}};
        OperationAccepted1 <= 1'b0;
`ifdef SUPERSCALAR
        ReadData2 <= {WORDBITS{1'b0}};
        DataValid2 <= 1'b0;
`endif
        read_2DM <= 1'b0;
        write_2DM <= 1'b0;
        address_2DM <= {(ADDRESSBITS){1'b0}};
        data_2DM <= {(`LINEBYTES){8'd0}};
        for(line_i = 0; line_i < `LINECOUNT; line_i = line_i + 1) begin
            lines[line_i[`LINECOUNTBITS-1:0]] = {`LINEBYTES{8'd0}};
            tags[line_i[`LINECOUNTBITS-1:0]] = {`TAGBITS{1'b0}};
            last_used_line[line_i[`LINECOUNTBITS-1:0]] = {`WAYBITS{1'b0}};
            line_is_dirty[line_i[`LINECOUNTBITS-1:0]] = 1'b0;
            line_is_valid[line_i[`LINECOUNTBITS-1:0]] = 1'b0;
            line_incoming[line_i[`LINECOUNTBITS-1:0]] = 1'b0;
        end
        incoming_line <= {`LINECOUNTBITS{1'b0}};
		line_fetch_counter <= {`LINEWORDBITS{1'b0}};
        in_flush <= 1'b0;
        got_readin = 1'b0;
        readin_no_wait = 1'b1;
    end else if(!CLK) begin
        OperationAccepted1 <= 1'b0;
        if(Flush1) begin
            $display("CACHE%s:Flushing...",CACHENAME);
			if(!in_flush) flush_position = 0;            
			in_flush <= 1'b1;
            need_writeback = 0;
            
            if(line_incoming[incoming_line]) begin
				line_fetch_counter <= {`LINEWORDBITS{1'b0}};
                line_incoming[incoming_line] =1'b0;
            end// else begin
                while((flush_position < `LINECOUNT) && !need_writeback) begin
                    requested_line = flush_position[`LINECOUNTBITS-1:0];
                    need_writeback = line_is_dirty[requested_line];
                    line_is_valid[requested_line] = 1'b0;
                    if(!need_writeback) flush_position = flush_position + 1;
                end
                if(flush_position == `LINECOUNT) begin
                    OperationAccepted1 <= 1'b1;
                    in_flush <= 1'b0;
                end
            //end
        end else if(Read1 || Write1) begin
            //$display("CACHE%s:NewAddress %x(Read=%d,Write=%d)",CACHENAME,Address1,Read1,Write1);
            set_found = 0;
            need_writeback = 0;
            need_readin = 0;
            requested_tag = Address1[ADDRESSBITS-1:`INDEXBITS+`BYTEBITS];
            requested_index = Address1[`INDEXBITS+`BYTEBITS-1:`BYTEBITS];
            requested_line[`LINECOUNTBITS-1:`WAYBITS] = requested_index;
            requested_byte = Address1[`BYTEBITS-1:0];
            requested_word = requested_byte[`BYTEBITS-1:`BYTEBITS-`LINEWORDBITS];
        
            for (set_line_i = 0; set_line_i < WAYS && !set_found; set_line_i = set_line_i + 1) begin
                requested_line[`WAYBITS-1:0] = set_line_i[`WAYBITS-1:0];
                //$display("CACHE%s:Evaluating line=%d: tag[line]=%x; requested_tag=%x; valid=%d",CACHENAME,requested_line, tags[requested_line], requested_tag, line_is_valid[requested_line]);
                if (tags[requested_line] == requested_tag && line_is_valid[requested_line])set_found = 1;
            end
            //$display("CACHE%s:Found=%d,line=%d",CACHENAME,set_found,requested_line);
            if (!set_found) begin
                //We haven't found the requested tag in the cache.
                need_readin = 1;
                //First check for non-dirty not-last-used line
                for (set_line_i = 0; set_line_i < WAYS && !set_found; set_line_i = set_line_i + 1) begin
                    requested_line[`WAYBITS-1:0] = set_line_i[`WAYBITS-1:0];
                    //$display("CACHE%s:Evaluating line=%d: valid=%d, last_used=%d, dirty=%d",CACHENAME,requested_line, line_is_valid[requested_line], last_used_line[requested_line], line_is_dirty[requested_line]);
                    if ((!line_is_valid[requested_line]) || ( !((last_used_line[requested_line]!={`WAYBITS{1'b0}}) || line_is_dirty[requested_line])))set_found = 1;
                end
            end
            //$display("CACHE%s:Found=%d,need_read=%d,line=%d",CACHENAME,set_found,need_readin,requested_line);
            if (!set_found) begin
                //Now, look for any not-last-used line
                //We will need a writeback if we've gotten here
                need_writeback = 1;
                for (set_line_i = 0; set_line_i < WAYS && !set_found; set_line_i = set_line_i + 1) begin
                    requested_line[`WAYBITS-1:0] = set_line_i[`WAYBITS-1:0];
                    //$display("CACHE%s:Evaluating line=%d: last_used=%d",CACHENAME,requested_line,last_used_line[requested_line]);
                    if (last_used_line[requested_line]=={`WAYBITS{1'b0}} || (WAYS<2))set_found = 1;
                end
            end
            $display("CACHE%s:NewAddress=%x,Found=%d,need_read=%d,need_write=%d,line=%d",CACHENAME,Address1,set_found,need_readin,need_writeback,requested_line);
            OperationAccepted1 <= (!need_readin) && (!line_incoming[requested_line]);
`ifdef SUPERSCALAR
            DataValid2 <= ({1'b0,requested_word} < (LINEWORDS - 1)) && (!need_readin) && (!line_incoming[requested_line]);
`endif
            if((!need_readin) && (!line_incoming[requested_line])) begin
                if(Read1 || Write1) begin
                    for (set_line_i = 0; set_line_i < WAYS; set_line_i = set_line_i + 1) begin
                        if(set_line_i[`WAYBITS-1:0] == requested_line[`WAYBITS-1:0]) begin
                           last_used_line[{requested_index,set_line_i[`WAYBITS-1:0]}] <= {`WAYBITS{1'b1}};
                        end else begin
                            last_used_line[{requested_index,set_line_i[`WAYBITS-1:0]}] <= (last_used_line[{requested_index,set_line_i[`WAYBITS-1:0]}] == {`WAYBITS{1'b0}})?{`WAYBITS{1'b0}}:(last_used_line[{requested_index,set_line_i[`WAYBITS-1:0]}]-1);
                        end
                    end
                end
                if(Read1) begin
                    temp_data = lines[requested_line] << (WORDBITS*requested_word);
                    ReadData1 <= temp_data[`LINEBITS-1:`LINEBITS-WORDBITS];
                    $display("CACHE%s:Read %x from %x",CACHENAME, temp_data[`LINEBITS-1:`LINEBITS-WORDBITS], Address1);
`ifdef SUPERSCALAR
                    if (({1'b0,requested_word} < (LINEWORDS - 1)) && (!need_readin) && (!line_incoming[requested_line])) begin
                        temp_data = lines[requested_line] << (WORDBITS*({3'd0,requested_word} + 1));
                        ReadData2 <= temp_data[`LINEBITS-1:`LINEBITS-WORDBITS];
                        $display("CACHE%s:Read %x from %x",CACHENAME, temp_data[`LINEBITS-1:`LINEBITS-WORDBITS], Address1+4);
                    end
`endif
                end else if(Write1) begin
                    temp_data_mask = 0;
                    temp_data_mask[`LINEBITS-1:`LINEBITS-WORDBITS] = WriteBits1;
                    temp_data[`LINEBITS-1:`LINEBITS-WORDBITS] = tWriteData1;
                    //$display("CACHE%s:ReqByte=%d;WriteSize=%d",CACHENAME,requested_byte,WriteSize1);
                    temp_data = temp_data >> 8*requested_byte;
                    temp_data_mask = temp_data_mask >> 8*requested_byte;
                    //$display("CACHE%s:TD =%x",CACHENAME,temp_data);
                    //$display("CACHE%s:TDM=%x",CACHENAME,temp_data_mask);
                    lines[requested_line] <= (lines[requested_line] & ~temp_data_mask) | (temp_data & temp_data_mask);
                    line_is_dirty[requested_line] <= 1'b1;
                    $display("CACHE%s:Wrote %x to %x",CACHENAME, tWriteData1 & WriteBits1, Address1);
                    //$display("CACHE%s:Line now %x",CACHENAME,(lines[requested_line] & ~temp_data_mask) | (temp_data & temp_data_mask));
                    //$display("CACHE%s:Byte Ref %x",CACHENAME,255'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f);
                end
            end
        end
        if(!line_incoming[incoming_line]) begin
            if (need_writeback) begin
                temp_address = {tags[requested_line],requested_line[`LINECOUNTBITS-1:`WAYBITS],{`BYTEBITS{1'b0}}};
                write_2DM <= 1'b1;
                address_2DM <= temp_address;
                data_2DM <= lines[requested_line];
                //$display("CACHE%s:requesting writeback of %x to %x",CACHENAME,lines[requested_line], temp_address);
                $display("CACHE%s:requesting writeback to %x",CACHENAME, temp_address);
                readin_no_wait = 1'b0;
            end else if (need_readin) begin
                if (!readin_no_wait) begin
                    readin_no_wait = 1'b1;
                    $display("CACHE%s:read_in waiting",CACHENAME);
                end else begin
                    temp_address = {requested_tag,requested_index,{`BYTEBITS{1'b0}}};
                    read_2DM <= 1'b1;
                    address_2DM <= temp_address;
                    $display("CACHE%s: requesting readin from %x",CACHENAME, temp_address);
                end
            end
        end
    end else if(CLK) begin
        got_readin = 1'b0;
        if (need_writeback) begin
            temp_address = {tags[requested_line],requested_line[`LINECOUNTBITS-1:`WAYBITS],{`BYTEBITS{1'b0}}};
            if(write_2DM && (address_2DM == temp_address)) begin
                if(dm_operation_accepted) begin
                    write_2DM <= 1'b0;
                    need_writeback = 1'b0;
                    line_is_dirty[requested_line] <= 1'b0;
                    $display("CACHE%s:writeback to %x finished",CACHENAME,temp_address);
                end
            end
        end else if(need_readin) begin
            if(read_2DM && (address_2DM == temp_address)) begin
                if(dm_operation_accepted) begin
                    temp_address = {requested_tag,requested_index,{`BYTEBITS{1'b0}}};
                    read_2DM <= 1'b0;
                    need_readin = 1'b0;
                    tags[requested_line] <= requested_tag;
                    lines[requested_line] <= data_fDM;
                    line_incoming[requested_line] <= 1'b1;
                    line_is_valid[requested_line] <= 1'b1;
                    line_fetch_counter <= {`LINEWORDBITS{1'b1}};
                    incoming_line <= requested_line;
                    $display("CACHE%s: received %x from %x saved to line %d",CACHENAME, data_fDM, temp_address,requested_line);
                    //$display("CACHE%s: received from %x saved to line %d",CACHENAME, temp_address,requested_line);
                    got_readin = 1'b1;
                end
            end
        end 
        if(!got_readin) begin
			if(line_incoming[incoming_line]) begin
				line_fetch_counter <= line_fetch_counter - 1;
				$display("CACHE%s:line_fetch_counter=%d",CACHENAME,line_fetch_counter);
            end
            if(line_fetch_counter == {`LINEWORDBITS{1'b0}}) begin
                line_incoming[incoming_line] <= 1'b0;
            end else begin
            end
        end
    end
end
    /*verilator lint_on BLKSEQ*/

endmodule

