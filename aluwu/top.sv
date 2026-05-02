`timescale 1ns / 1ps

/*
* Top-level module for ALUwU
*
* - Interfaces external inputs/outputs with internal FP units
* - Registers inputs at start to keep operation stable
* - Instantiates control FSM and arithmetic units (add, mul, div)
* - Selects the correct result based on operation
* - Latches final result when valid_out is asserted
*
* Data flow:
*   Inputs -> Registers -> FP Units -> MUX -> Output Register
*
* Control flow:
*   start -> control FSM -> start_* -> FP unit -> done_* -> valid_out
*
* Notes:
* - op_code:
*     000: ADD
*     001: SUB (handled inside fp_add)
*     010: MUL
*     011: DIV
* - mode_fp and round_mode: reserved for future FP features
* - flags: not implemented yet
*/

module top(input [31:0] op_a,
            input [31:0] op_b,
            input [2:0] op_code,
            input mode_fp,
            input clk,
            input rst,
            input round_mode,
            input start,
            output [31:0] result,
            output valid_out,
            output [4:0] flags);
  
  // Control signals between FSM and FP units
  wire start_add, start_mul, start_div;
  wire done_add, done_mul, done_div;
  
  // Results from FP units
  wire [31:0] result_add, result_mul, result_div;
  
  // Internal result signals
  reg [31:0] result_reg;
  reg [31:0] result_out;
  
  // Latched inputs (to avoid changes during execution)
  reg [2:0] op_code_reg;
  reg [31:0] op_a_reg;
  reg [31:0] op_b_reg;
  
  /*
  * Input register stage
  * Captures operands and operation when start is asserted
  */
  always @(posedge clk or posedge rst) begin
    if (rst)
      begin
        op_code_reg <= 3'b000;
        op_a_reg <= 0;
        op_b_reg <= 0;
      end
    else if (start)
      begin
        op_code_reg <= op_code;
        op_a_reg <= op_a;
        op_b_reg <= op_b;
      end
  end
  
  /*
  * Control FSM
  * Generates start pulses and valid_out signal
  */
  control ctrl(.clk(clk),
               .rst(rst),
               .start(start),
               .op_code(op_code),
               .done_add(done_add),
               .done_mul(done_mul),
               .done_div(done_div),
               .start_add(start_add),
               .start_mul(start_mul),
               .start_div(start_div),
               .valid_out(valid_out));
  
  /*
  * Floating-point units
  */
  
  // Adder/Subtractor
  fp_add add(.clk(clk),
             .start(start_add),
             .op(op_code_reg),
             .a(op_a_reg),
             .b(op_b_reg),
             .result(result_add),
             .done(done_add));
  
  // Multiplier
  fp_mul mul(.clk(clk),
             .start(start_mul),
             .a(op_a_reg),
             .b(op_b_reg),
             .result(result_mul),
             .done(done_mul));
  
  // Divider
  fp_div div(.clk(clk),
             .start(start_div),
             .a(op_a_reg),
             .b(op_b_reg),
             .result(result_div),
             .done(done_div));
  
  /*
  * Result selection (MUX)
  * Chooses output from the active unit
  */
  always @(*) begin
    case(op_code_reg)
      3'b000: result_reg = result_add;
      3'b001: result_reg = result_add;
      3'b010: result_reg = result_mul;
      3'b011: result_reg = result_div;
      default: result_reg = 32'b0;
    endcase
  end
  
  /*
  * Output register
  * Stores result when computation is finished
  */
  always @(posedge clk or posedge rst) begin
    if (rst)
      result_out <= 0;
    else if (valid_out)
      result_out <= result_reg;
  end
  
  // Final outputs
  assign result = result_out;
  
  // Exception flags (not implemented yet)
  assign flags = 5'b0;
  
endmodule
