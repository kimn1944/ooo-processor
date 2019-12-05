/*
* File: TABLE_obj.v
* Author: Nikita Kim & Celine Wang
* Email: kimn1944@gmail.com
* Date: 12/3/19
*/

`include "config.v"

module TABLE_obj
    #(parameter temp = 1,
      parameter tag = "Table")
    (input clk,
      input reset,
      input stall,

      input [4:0] RegA,
      input [4:0] RegB,
      input [4:0] RegC,

      output [5:0] MapA,
      output [5:0] MapB,
      output [5:0] MapC,

      input [4:0] reg_to_map,
      input [5:0] new_mapping,
      input remap,

      input [5:0] new_map [31:0],
      input overwrite,

      output [5:0] my_map [31:0]);

    integer i;
    reg [5:0] arr [31:0]/*verilator public*/;

    always @ * begin
        MapA <= arr[RegA];
        MapB <= arr[RegB];
        MapC <= arr[RegC];
        my_map <= arr;
    end

    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            for(i = 0; i < 32; i = i + 1) begin
                arr[i] = temp ? i : 31 - i;
            end
        end
        else if(!stall) begin
            if(overwrite) begin
                arr <= new_map;
            end
            else begin
                arr[reg_to_map] <= remap ? new_mapping : arr[reg_to_map];
            end
        end
        `ifdef TABLE
            $display("%s", tag);
            $display("Reg to remap: %x, New mapping: %x", reg_to_map, new_mapping);
            $display("Remap: %x, Overwrite: %x", remap, overwrite);
            $display("Arr[0]: %d", arr[0]);
            $display("End %s", tag);
        `endif
    end

endmodule
