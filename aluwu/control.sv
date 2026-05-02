`timescale 1ns / 1ps

/*
 * Control FSM for ALUwU
 *
 * - Orchestrates execution of fp_add, fp_mul, fp_div
 * - Issues single-cycle start pulses
 * - Waits for corresponding done signal
 * - Generates valid_out when result is ready
 *
 * State flow:
 *   IDLE -> EXEC -> DONE -> IDLE
 */

module control(
  input clk,
  input rst,
  input start,
  input [2:0] op_code,
  input done_add,
  input done_mul,
  input done_div,
  output reg start_add,
  output reg start_mul,
  output reg start_div,
  output reg valid_out
);
  
  // FSM states (binary encoding)
  localparam IDLE = 2'b00;
  localparam EXEC = 2'b01;
  localparam DONE = 2'b10;
  
  reg [1:0] state;
  reg [1:0] next_state;
  
  // State register (sequential)
  always @(posedge clk or posedge rst) begin
    if (rst)
      state <= IDLE;
    else
      state <= next_state;
  end
  
  // Next-state logic (combinational)
  always @(*) begin
    next_state = state;

    case(state)
      // Wait for a new operation request
      IDLE:
        if (start)
            next_state = EXEC;
	  
      // Wait until selected unit finishes
      EXEC:
        case(op_code)
            3'b000, 3'b001: if (done_add) next_state = DONE;
            3'b010:         if (done_mul) next_state = DONE;
            3'b011:         if (done_div) next_state = DONE;
            default:        next_state = DONE;
          endcase
	  
      // One-cycle completion state
      DONE:
        next_state = IDLE;
    endcase
  end
  
  // Output logic (combinational)
  always @(*) begin
    start_add = 0;
    start_mul = 0;
    start_div = 0;
    valid_out = 0;

    case(state)
      // Issue start pulse based on operation
      IDLE:
          if (start)
            case(op_code)
                3'b000, 3'b001: start_add = 1;
                3'b010:         start_mul = 1;
                3'b011:         start_div = 1;
              endcase
      
	  // Signal result is ready (1 cycle pulse)
      DONE:
        valid_out = 1;
    endcase
  end

endmodule
