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

      input [5:0] reg_to_update1,
      input [31:0] new_value1,
      input update1,

      input [5:0] reg_to_update2,
      input [31:0] new_value2,
      input update2,

      output [31:0] regs [63:0]);

      integer i;
      reg [31:0] arr [63:0]/*verilator public*/;

      assign regs = arr;

      always @(negedge clk or negedge reset) begin
          if(!reset) begin
              for(i = 0; i < 64; i = i + 1) begin
                  arr[i] = 0;
              end
          end
          else if(!stall) begin
              if(reg_to_update1 != 0) begin
                  arr[reg_to_update1] <= update1 ? new_value1 : arr[reg_to_update1];
              end
              if(reg_to_update2 != 0) begin
                  arr[reg_to_update2] <= update2 ? new_value2 : arr[reg_to_update2];
              end
          end
      end

      always @(posedge clk) begin
          `ifdef PHYSREG
              $display("\t\t\t\tPHYSREG");
              for(i = 0; i < 32; i = i + 1) begin
                  if((i == reg_to_update1) && update1) begin
                      $display("[%d] : %x   <<<--- %x [E]         [%d] : %x", i, arr[i], i + 32, new_value1, arr[i + 32]);
                  end
                  else if(((i + 32) == reg_to_update1) && update1) begin
                      $display("[%d] : %x                     [%d] : %x   <<<--- %x [E]", i, arr[i], i + 32, arr[i + 32], new_value1);
                  end
                  else if((i == reg_to_update2) && update2) begin
                      $display("[%d] : %x   <<<--- %x [M]         [%d] : %x", i, arr[i], new_value2, i + 32, arr[i + 32]);
                  end
                  else if(((i + 32) == reg_to_update2) && update2) begin
                      $display("[%d] : %x                     [%d] : %x   <<<--- %x [M]", i, arr[i], i + 32, arr[i + 32], new_value2);
                  end
                  else begin
                      $display("[%d] : %x                     [%d] : %x", i, arr[i], i + 32, arr[i + 32]);
                  end
              end
              $display("\t\t\t\tEND PHYSREG");
          `endif
      end


endmodule
