/*
* File: Queue.v
* Author: Nikita Kim
* Email: kimn1944@gmail.com
* Date: 12/3/19
*/

`include "config.v"

module QUEUE_obj
    #(parameter LENGTH = 8,
      parameter WIDTH = 32)
    (input clk,
      input reset,
      input stall,
      input flush,

      input enque,
      input [WIDTH - 1:0] enque_data,

      input deque,
      output reg [WIDTH - 1:0] deque_data,
      output reg halt);

    integer i;
    integer head;
    integer tail;
    integer size;
    reg [WIDTH - 1:0] queue [LENGTH - 1:0];

    always @ * begin
        halt <= (size == LENGTH);
    end

    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            for(i = 0; i < LENGTH; i = i + 1) begin
                queue[i] = 0;
            end
            deque_data <= 0;
            head <= 0;
            tail <= 0;
            size <= 0;
        end
        else if(flush) begin
            for(i = 0; i < LENGTH; i = i + 1) begin
                queue[i] = 0;
            end
            deque_data <= 0;
            head <= 0;
            tail <= 0;
            size <= 0;
        end
        else if(clk) begin
            deque_data <= (deque & ~stall & (size > 0)) ? queue[head] : 0;
            head       <= (deque & ~stall & (size > 0)) ? ((head < LENGTH - 1) ? head + 1 : 0) : head;

            queue[tail] <= (enque & ~halt & (size < LENGTH)) ? enque_data : queue[tail];
            tail        <= (enque & ~halt & (size < LENGTH)) ? ((tail < LENGTH - 1) ? tail + 1 : 0) : tail;

            size <= (enque & ~halt & (size < LENGTH)) ? ((deque & ~stall & (size > 0)) ? size : size + 1) : ((deque & ~stall & (size > 0)) ? size - 1 : size);
        end

        `ifdef QUEUE
            $display("Queue");
            $display("Queue: %x, Size: %d, Head: %d, Tail: %d", queue[0], size, head, tail);
            $display("Enq Data[%x]: %x, Deq Data[%x]: %x", enque, enque_data, deque, deque_data);
            $display("Stall: %x, Halt: %x, Flush: %x", stall, halt, flush);
            $display("END Queue");
        `endif
    end


endmodule
