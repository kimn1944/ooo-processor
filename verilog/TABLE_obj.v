/*
* File: TABLE_obj.v
* Author: Nikita Kim & Celine Wang
* Email: kimn1944@gmail.com
* Date: 12/3/19
*/

`include "config.v"

module TABLE_obj
    #(parameter tag = "Table")
    (input clk,
      input reset,
      input stall,

      input [4:0] reg_to_map,
      input [5:0] new_mapping,
      input remap,

      input [5:0] new_map [31:0],
      input overwrite,

      output [5:0] returned_mapping,
      output return_map,

      output [5:0] my_map [31:0]);

    integer i;
    reg [5:0] arr [31:0]/*verilator public*/;

    assign my_map = arr;

    always @(negedge clk or negedge reset) begin
        if(!reset) begin
            for(i = 0; i < 32; i = i + 1) begin
                arr[i] = i;
            end
        end
        else if(!stall) begin
            if(overwrite) begin
                arr <= new_map;
            end
            else begin
                arr[reg_to_map] <= (remap & (reg_to_map != 0)) ? new_mapping : arr[reg_to_map];
                returned_mapping <= (remap & (reg_to_map != 0)) ? arr[reg_to_map] : 0;
                return_map <= (remap & (reg_to_map != 0)) ? 1 : 0;
            end
        end
        `ifdef TABLE
            $display("\t\t\t\t%s", tag);
            $display("Remap: %x", remap);
            for(i = 0; i < 32; i = i + 1) begin
                if((i == reg_to_map) & remap) begin
                    $display("%s[%d]: %d   <<<--- %d", tag, i, arr[i], new_mapping);
                end
                else begin
                    $display("%s[%d]: %d", tag, i, arr[i]);
                end
            end
            $display("\t\t\t\tEnd %s\n", tag);
        `endif
    end

endmodule
