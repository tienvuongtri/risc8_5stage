`timescale 1ns / 1ps

// 256 x 8 data memory: asynchronous read, synchronous write.
module dmem (
    input  wire       clk,
    input  wire [7:0] address,
    input  wire [7:0] write_data,
    input  wire       write_enable,
    output wire [7:0] read_data
);
    reg [7:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'h00;
    end

    always @(posedge clk) begin
        if (write_enable)
            mem[address] <= write_data;
    end

    assign read_data = mem[address];
endmodule
