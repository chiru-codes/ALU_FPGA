`timescale 1ns / 1ps

/*
* Floating-point adder (fp_add)
*
* - Performs IEEE-754 single-precision addition and subtraction
* - Supports operations:
*     000 -> ADD
*     001 -> SUB (implemented via sign inversion)
* - Uses start/done handshake protocol
*
* Inputs:
*   - a, b: 32-bit IEEE-754 operands
*   - op: operation selector
*
* Outputs:
*   - result: 32-bit IEEE-754 result
*   - done: single-cycle pulse when result is ready
*
* Internal pipeline stages:
*   UNPACK -> ALIGN -> ADD/SUB -> NORMALIZE -> ROUND -> PACK
*
* Rounding:
*   - Round to nearest, ties to even (RNE)
*   - Uses guard, round, and sticky bits
*/

module fp_add(input  wire clk,
              input  wire rst,
              input  wire start,
              input  wire [2:0] op,
              input  wire [31:0] a,
              input  wire [31:0] b,
              output reg [31:0] result,
              output reg done);
  
    // Internal signals and work logs
    reg [7:0] exp_a_reg, exp_b_reg, exp_res;
    reg [26:0] mant_a_reg, mant_b_reg, mant_sum;
    reg sign_a_reg, sign_b_reg, sign_res;
    reg busy;
    reg sticky;  // rounding bit

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy     <= 1'b0;
            done     <= 1'b0;
            result   <= 32'b0;
        end else begin
            if (start) begin
                /*
                * STEP 1: Unpacking and Alignment
                */
                // Extract the sign and adjust sign_b based on the SUB operation
                sign_a_reg <= a[31];
                sign_b_reg <= (op == 3'b001) ? ~b[31] : b[31];
                // Extracting exponents and fractions
                exp_a_reg <= a[30:23];
                exp_b_reg <= b[30:23];
                // Construct mantisas with a hidden bit and 3 extra bits (<<3)
                if (exp_a_reg == 8'b0)
                    mant_a_reg <= {1'b0, a[22:0], 3'b000};
                else
                    mant_a_reg <= {1'b1, a[22:0], 3'b000};
                if (exp_b_reg == 8'b0)
                    mant_b_reg <= {1'b0, b[22:0], 3'b000};
                else
                    mant_b_reg <= {1'b1, b[22:0], 3'b000};

                // Align the mantissas by shifting the one with the smallest exponent
                if (exp_a_reg > exp_b_reg) begin
                    exp_res  <= exp_a_reg;
                    // If the difference is large, set `mant_b` to 0 and mark it as sticky
                    if (exp_a_reg - exp_b_reg >= 27) begin
                        sticky    <= |mant_b_reg; 
                        mant_b_reg <= 27'b0;
                    end else begin
                        // Shift with sticky of missing bits
                        sticky    <= |(mant_b_reg[exp_a_reg-exp_b_reg-1:0]);
                        mant_b_reg <= mant_b_reg >> (exp_a_reg - exp_b_reg);
                    end
                end else begin
                    exp_res  <= exp_b_reg;
                    if (exp_b_reg - exp_a_reg >= 27) begin
                        sticky    <= |mant_a_reg;
                        mant_a_reg <= 27'b0;
                    end else begin
                        sticky    <= |(mant_a_reg[exp_b_reg-exp_a_reg-1:0]);
                        mant_a_reg <= mant_a_reg >> (exp_b_reg - exp_a_reg);
                    end
                end

                busy <= 1'b1; 
                done <= 1'b0;
            end 
            else if (busy) begin
                /*
                * STEP 2: Addition/Subtraction of mantissas
                */
                if (sign_a_reg == sign_b_reg) begin
                    mant_sum = mant_a_reg + mant_b_reg;
                    sign_res = sign_a_reg;
                end else if (mant_a_reg >= mant_b_reg) begin
                    mant_sum = mant_a_reg - mant_b_reg;
                    sign_res = sign_a_reg;
                end else begin
                    mant_sum = mant_b_reg - mant_a_reg;
                    sign_res = sign_b_reg;
                end

                /*
                * STEP 3: Preliminary standardization
                */
                // If there is a carry (bit 26=1), we shift and increase the exponent
                if (mant_sum[26]) begin
                    sticky   <= sticky | mant_sum[0];
                    mant_sum <= mant_sum >> 1;
                    exp_res  <= exp_res + 1;
                end else begin
                    // Shift left until normalized (bit 25 = 1) or the exponent reaches 0
                    while (mant_sum[25] == 1'b0 && exp_res > 8'b0) begin
                        mant_sum <= mant_sum << 1;
                        exp_res  <= exp_res - 1;
                    end
                end

                /*
                * STEP 4: RNE Rounding (use guard/round/sticky)
                */
                // The guard, round, and sticky bits in mant_sum[2], [1], and [0], respectively
                if (mant_sum[2] && (mant_sum[1] || sticky || mant_sum[3])) begin
                    // Increase the mantissa by rounding (add 1 to bit 3)
                    mant_sum <= mant_sum + 27'b000000000000000000000000100;
                    // Possible new carryover after rounding
                    if (mant_sum[26]) begin
                        // Carryover occurred when adding (it was previously at 25)
                        mant_sum <= mant_sum >> 1;
                        exp_res  <= exp_res + 1;
                    end
                end

                /*
                * STEP 5: Final Packaging
                */
                if (exp_res >= 8'hFF) begin
                    // Overflow -> ±∞
                    result <= {sign_res, 8'hFF, 23'b0};
                end else if (exp_res == 8'b0) begin
                    // Underflow -> zero/subnormal minimum (exp 0)
                    result <= 32'b0;
                end else begin
                    // Cut the standardized mantis (bits 25:3)
                    result <= {sign_res, exp_res, mant_sum[25:3]};
                end

                done <= 1'b1;
                busy <= 1'b0;
            end 
            else begin
                // On hold / Clear donation flag
                done <= 1'b0;
            end
        end
    end
endmodule
