/*
* File: PHYS_REG.v
* Author: Nikita Kim & Celine Wang
* Email: kimn1944@gmail.com
* Date: 12/3/19
*/

`include "config.v"

module PHYS_REG
    #()
    (input clk,
      input reset,
      input stall,

      input [5:0] reg_to_update,
      input [31:0] new_value,
      input update,

      output [31:0] regs [63:0]);

      integer i;
      reg [31:0] arr [63:0]/*verilator public*/;

      assign regs = arr;

      always @(posedge clk or negedge reset) begin
          if(!reset) begin
              for(i = 0; i < 64; i = i + 1) begin
                  arr[i] = 0;
              end
          end
          else if(!stall) begin
              arr[reg_to_update] <= update ? new_value : arr[reg_to_update];
          end
      end



endmodule
