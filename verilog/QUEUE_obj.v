/*
* File: QUEUE_obj.v
* Author: Nikita Kim & Celine Wang
* Email: kimn1944@gmail.com
* Date: 12/3/19
*/

`include "config.v"

module QUEUE_obj
    #(parameter SPECIAL = 0,
      parameter INIT = 0,
      parameter LENGTH = 8,
      parameter WIDTH = 32,
      parameter TAG = "Queue")
    (input clk,
      input reset,
      input stall,
      input flush,

      input enque,
      input [WIDTH - 1:0] enque_data,

      input deque,
      output reg [WIDTH - 1:0] deque_data,

      input [5:0] r_mapping [31:0],
      output reg halt);

    integer i;
    integer head;
    integer tail;
    integer size;
    reg [WIDTH - 1:0] queue [LENGTH - 1:0];

    if(INIT) begin
        assign halt = (size == 0);
    end
    else begin
        assign halt = (size == LENGTH);
    end

    reg [63:0] temp;
    integer j;

    assign deque_data = (deque & ~stall & (size > 0)) ? queue[head] : 0;
    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            if(INIT == 0) begin
                for(i = 0; i < LENGTH; i = i + 1) begin
                    queue[i] = 0;
                end
                head <= 0;
                tail <= 0;
                size <= 0;
            end
            else begin
                for(i = 0; i < LENGTH; i = i + 1) begin
                    queue[i] = LENGTH + i;
                end
                head <= 0;
                tail <= LENGTH - 1;
                size <= LENGTH;
            end
        end
        else if(flush) begin
            if(INIT) begin
                temp = {64{1'b1}};
                for(i = 0; i < 32; i = i + 1) begin
                    temp[r_mapping[i]] = 0;
                end
                j = 0;
                for(i = 0; i < 64; i = i + 1) begin
                    if(temp[i] == 1) begin
                        queue[j] = i;
                        j = j + 1;
                    end
                end
                head <= 0;
                tail <= LENGTH - 1;
                size <= LENGTH;
            end
            else begin
                if(SPECIAL) begin
                    queue[i] = queue[head];
                    for(i = 1; i < LENGTH; i = i + 1) begin
                        queue[i] = 0;
                    end
                    head <= 0;
                    tail <= 1;
                    size <= 1;
                end
                else begin
                    for(i = 0; i < LENGTH; i = i + 1) begin
                        queue[i] = 0;
                    end
                    head <= 0;
                    tail <= 0;
                    size <= 0;
                end
            end
        end
        else if(clk) begin
            head       <= (deque & ~stall & (size > 0)) ? ((head < LENGTH - 1) ? head + 1 : 0) : head;

            if(INIT) begin
                queue[tail] <= (enque & (size < LENGTH)) ? enque_data : queue[tail];
                tail        <= (enque & (size < LENGTH)) ? ((tail < LENGTH - 1) ? tail + 1 : 0) : tail;
                size <= (enque & (size < LENGTH)) ? ((deque & ~stall & (size > 0)) ? size : size + 1) : ((deque & ~stall & (size > 0)) ? size - 1 : size);
            end
            else begin
                queue[tail] <= (enque & ~halt & (size < LENGTH)) ? enque_data : queue[tail];
                tail        <= (enque & ~halt & (size < LENGTH)) ? ((tail < LENGTH - 1) ? tail + 1 : 0) : tail;
                size <= (enque & ~halt & (size < LENGTH)) ? ((deque & ~stall & (size > 0)) ? size : size + 1) : ((deque & ~stall & (size > 0)) ? size - 1 : size);
            end
        end

        `ifdef QUEUE
            if(INIT) begin
                $display("\t\t\t\tFree List");
                $display("Queue: %x, Size: %d, Head: %d, Tail: %d", queue[0], size, (deque & ~stall & (size > 0)) ? ((head < LENGTH - 1) ? head + 1 : 0) : head, (enque & ~halt & (size < LENGTH)) ? ((tail < LENGTH - 1) ? tail + 1 : 0) : tail);
                $display("Enq Data[%x]: %x, Deq Data[%x]: %x", enque, enque_data, deque, (deque & ~stall & (size > 0)) ? queue[head] : 0);
                $display("Stall: %x, Halt: %x, Flush: %x, Reset: %x", stall, halt, flush, ~reset);
                for(i = 0; i < LENGTH; i = i + 1) begin
                    if(i == head) begin
                        $display("Free List[%d]: %d   <<<--- HEAD", i, queue[i]);
                    end
                    else if(i == tail) begin
                        $display("Free List[%d]: %d   <<<--- TAIL", i, queue[i]);
                    end
                    else begin
                        $display("Free List[%d]: %d", i, queue[i]);
                    end
                end
                $display("\t\t\t\tEND Free List\n");
            end
        `endif
    end


endmodule
