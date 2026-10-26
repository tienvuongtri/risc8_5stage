`timescale 1ns / 1ps

// R0 is a normal writable register. Reads are asynchronous, write is clocked.
module regfile (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] read_addr_a,
    input  wire [2:0] read_addr_b,
    output wire [7:0] read_data_a,
    output wire [7:0] read_data_b,
    input  wire [2:0] write_addr,
    input  wire [7:0] write_data,
    input  wire       write_enable
);
    reg [7:0] regs [0:7];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1)
                regs[i] <= 8'h00;
        end else if (write_enable) begin
            regs[write_addr] <= write_data;
        end
    end

    // WB-to-ID bypass covers a read and write of the same register in one cycle.
    assign read_data_a = (write_enable && write_addr == read_addr_a)
                       ? write_data : regs[read_addr_a];
    assign read_data_b = (write_enable && write_addr == read_addr_b)
                       ? write_data : regs[read_addr_b];
endmodule
