// Code your design here
`timescale 1ns / 1ns

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
  
  wire start_add, start_mul, start_div;
  wire done_add, done_mul, done_div;
  wire [31:0] result_add, result_mul, result_div;
  
  reg [31:0] result_reg;
  reg [31:0] result_out;
  
  reg [2:0] op_code_reg;
  reg [31:0] op_a_reg;
  reg [31:0] op_b_reg;
  
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
  
  fp_add add(.clk(clk),
             .start(start_add),
             .op(op_code_reg),
             .a(op_a_reg),
             .b(op_b_reg),
             .result(result_add),
             .done(done_add));
  
  fp_mul mul(.clk(clk),
             .start(start_mul),
             .a(op_a_reg),
             .b(op_b_reg),
             .result(result_mul),
             .done(done_mul));
  
  fp_div div(.clk(clk),
             .start(start_div),
             .a(op_a_reg),
             .b(op_b_reg),
             .result(result_div),
             .done(done_div));
  
  always @(*) begin
    case(op_code_reg)
      3'b000: result_reg = result_add;
      3'b001: result_reg = result_add;
      3'b010: result_reg = result_mul;
      3'b011: result_reg = result_div;
      default: result_reg = 32'b0;
    endcase
  end
  
  always @(posedge clk or posedge rst) begin
    if (rst)
      result_out <= 0;
    else if (valid_out)
      result_out <= result_reg;
  end
  
  assign result = result_out;
  
  assign flags = 5'b0;
  
endmodule
