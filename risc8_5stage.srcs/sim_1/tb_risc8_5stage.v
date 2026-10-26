`timescale 1ns / 1ps

module tb_risc8_5stage;
    reg clk;
    reg rst;
    wire halted;
    wire [7:0] pc_out;
    wire [1:0] flags_out;
    wire instr_done;

    integer cycles, retired, done_pulses, stalls, taken_branches;
    integer forwarded_a, forwarded_b, bypasses, checks, errors;

    risc8_5stage_core dut (
        .clk(clk),
        .rst(rst),
        .halted(halted),
        .pc_out(pc_out),
        .flags_out(flags_out),
        .instr_done(instr_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    task check_byte;
        input [8*50-1:0] name;
        input [7:0] actual;
        input [7:0] expected;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL %-50s got=%02h expected=%02h", name, actual, expected);
            end else
                $display("PASS %-50s value=%02h", name, actual);
        end
    endtask

    task check_number;
        input [8*50-1:0] name;
        input integer actual;
        input integer expected;
        begin
            checks = checks + 1;
            if (actual != expected) begin
                errors = errors + 1;
                $display("FAIL %-50s got=%0d expected=%0d", name, actual, expected);
            end else
                $display("PASS %-50s value=%0d", name, actual);
        end
    endtask

    task check_true;
        input [8*50-1:0] name;
        input condition;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL %-50s", name);
            end else
                $display("PASS %-50s", name);
        end
    endtask

    // Monitor old pipeline state at each edge, before nonblocking updates.
    always @(posedge clk) begin
        if (!rst && !halted) begin
            cycles = cycles + 1;
            if (dut.memwb_valid) begin
                retired = retired + 1;
                // Instructions on a flushed or post-HLT path must not retire.
                case (dut.memwb_pc)
                    8'd6, 8'd7, 8'd10, 8'd11, 8'd21, 8'd22,
                    8'd27, 8'd28, 8'd33, 8'd34, 8'd38, 8'd39,
                    8'd46, 8'd47: begin
                        errors = errors + 1;
                        $display("FAIL wrong-path instruction retired at PC=%0d", dut.memwb_pc);
                    end
                    default: begin end
                endcase
            end
            if (dut.stall)
                stalls = stalls + 1;
            if (dut.branch_taken)
                taken_branches = taken_branches + 1;
            if (dut.idex_valid && dut.fwd_a_sel != 2'b00)
                forwarded_a = forwarded_a + 1;
            if (dut.idex_valid && dut.fwd_b_sel != 2'b00)
                forwarded_b = forwarded_b + 1;
            if (dut.ifid_valid && dut.wb_write_enable &&
                ((dut.id_uses_a && dut.id_src_a == dut.memwb_rd) ||
                 (dut.id_uses_b && dut.id_src_b == dut.memwb_rd)))
                bypasses = bypasses + 1;

            // Focused EX-stage checks make ALU and flag semantics observable.
            if (dut.idex_valid) begin
                case (dut.idex_pc)
                    8'd4:  check_true("AND produces zero", dut.alu_result == 8'h00 && dut.alu_zero);
                    8'd19: check_true("ADDI wraps and raises carry", dut.alu_result == 8'h00 && dut.alu_carry);
                    8'd25: check_true("SUB borrows when 03 - 0F", dut.alu_result == 8'hF4 && dut.alu_carry);
                    8'd36: check_true("SHL shifts out bit 7", dut.alu_result == 8'h00 && dut.alu_carry);
                    8'd41: check_true("SHR shifts out bit 0", dut.alu_result == 8'h00 && dut.alu_carry);
                    default: begin end
                endcase
            end
        end
    end

    always @(negedge clk) begin
        if (!rst && instr_done)
            done_pulses = done_pulses + 1;
    end

    initial begin
        rst = 1'b1;
        cycles = 0;
        retired = 0;
        done_pulses = 0;
        stalls = 0;
        taken_branches = 0;
        forwarded_a = 0;
        forwarded_b = 0;
        bypasses = 0;
        checks = 0;
        errors = 0;

        repeat (2) @(negedge clk);
        rst = 1'b0;

        while (halted !== 1'b1 && cycles < 100)
            @(negedge clk);

        check_true("HLT retires within 100 cycles", halted);
        if (halted === 1'b1) begin
            check_byte("R0", dut.registers.regs[0], 8'h00);
            check_byte("R1", dut.registers.regs[1], 8'h05);
            check_byte("R2", dut.registers.regs[2], 8'h03);
            check_byte("R3", dut.registers.regs[3], 8'h08);
            check_byte("R4", dut.registers.regs[4], 8'h20);
            check_byte("R5", dut.registers.regs[5], 8'h08);
            check_byte("R6", dut.registers.regs[6], 8'h00);
            check_byte("R7", dut.registers.regs[7], 8'hFF);
            check_byte("data memory[0x20]", dut.data_memory.mem[8'h20], 8'h08);
            check_byte("flags {Z,C}", {6'b0, flags_out}, 8'h03);
            check_number("retired instructions", retired, 34);
            check_number("cycles through HLT", cycles, 51);
            check_number("instr_done pulses", done_pulses, 34);
            check_number("load-use stalls", stalls, 1);
            check_number("taken branches and jumps", taken_branches, 6);
            check_true("A forwarding exercised", forwarded_a > 0);
            check_true("B forwarding exercised", forwarded_b > 0);
            check_true("WB-to-ID bypass exercised", bypasses > 0);
        end

        if (errors == 0)
            $display("*** ALL TESTS PASSED: %0d checks ***", checks);
        else begin
            $display("*** TESTS FAILED: %0d errors in %0d checks ***", errors, checks);
            $fatal(1, "RISC8 regression failed");
        end
        $finish;
    end
endmodule
