`timescale 1ns / 1ps

// Unsigned 8-bit ALU. For SUB, C=1 means a borrow was required.
module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] op,
    output reg  [7:0] result,
    output reg        zero,
    output reg        carry
);
    reg [8:0] extended;

    always @* begin
        result   = 8'h00;
        zero     = 1'b1;
        carry    = 1'b0;
        extended = 9'h000;
        case (op)
            3'd0: begin // ADD
                extended = {1'b0, a} + {1'b0, b};
                result   = extended[7:0];
                carry    = extended[8];
                zero     = (a == (8'h00 - b));
            end
            3'd1: begin // SUB
                result = a - b;
                carry  = (a < b);
                zero   = (a == b);
            end
            3'd2: begin result = a & b; zero = ~|(a & b); end
            3'd3: begin result = a | b; zero = ~|(a | b); end
            3'd4: begin result = a ^ b; zero = (a == b); end
            3'd5: begin // SHL
                result = {a[6:0], 1'b0};
                carry  = a[7];
                zero   = ~|a[6:0];
            end
            3'd6: begin // SHR
                result = {1'b0, a[7:1]};
                carry  = a[0];
                zero   = ~|a[7:1];
            end
            3'd7: begin result = b; zero = ~|b; end // LDI
            default: result = 8'h00;
        endcase
    end

endmodule
