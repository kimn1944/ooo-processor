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

      input [5:0] A,
      input [5:0] B,
      input [5:0] C,

      output [31:0] ValA,
      output [31:0] ValB,
      output [31:0] ValC,

      input [5:0] reg_to_update,
      input [31:0] new_value,
      input update);

      integer i;
      reg [31:0] arr [63:0]/*verilator public*/;

      always @ * begin
          ValA <= arr[A];
          ValB <= arr[B];
          ValC <= arr[C];
      end

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
