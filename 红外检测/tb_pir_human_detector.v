`timescale 1ns / 1ps

module tb_pir_human_detector;

    reg clk;
    reg rst_n;
    reg pir_in;

    wire pir_raw_sync;
    wire pir_valid;
    wire human_present;

    integer errors;
    integer timeout_count;

    pir_human_detector #(
        .CLK_FREQ_HZ(100_000_000),
        .WARMUP_SEC(60),
        .STABLE_MS(100),
        .SIM_FAST(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pir_in(pir_in),
        .pir_raw_sync(pir_raw_sync),
        .pir_valid(pir_valid),
        .human_present(human_present)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_bit;
        input actual;
        input expected;
        input [255:0] name;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s: expected %0b got %0b at %0t",
                         name, expected, actual, $time);
                errors = errors + 1;
            end else begin
                $display("PASS %0s = %0b at %0t", name, actual, $time);
            end
        end
    endtask

    task set_pir;
        input value;
        begin
            @(negedge clk);
            pir_in = value;
        end
    endtask

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        pir_in = 1'b0;

        wait_cycles(5);
        rst_n = 1'b1;

        set_pir(1'b1);
        wait_cycles(8);
        check_bit(pir_valid, 1'b0, "warmup pir_valid");
        check_bit(human_present, 1'b0, "warmup human_present high input");

        set_pir(1'b0);
        wait_cycles(8);
        check_bit(pir_valid, 1'b0, "warmup pir_valid before done");
        check_bit(human_present, 1'b0, "warmup human_present low input");

        timeout_count = 0;
        while ((pir_valid !== 1'b1) && (timeout_count < 100)) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end

        check_bit(pir_valid, 1'b1, "pir_valid after warmup");
        check_bit(human_present, 1'b0, "human_present after warmup");

        set_pir(1'b1);
        wait_cycles(4);
        check_bit(human_present, 1'b0, "stable high before threshold");
        wait_cycles(4);
        check_bit(human_present, 1'b1, "stable high after threshold");

        set_pir(1'b0);
        wait_cycles(2);
        set_pir(1'b1);
        wait_cycles(8);
        check_bit(human_present, 1'b1, "short low glitch ignored");

        set_pir(1'b0);
        wait_cycles(4);
        check_bit(human_present, 1'b1, "stable low before threshold");
        wait_cycles(4);
        check_bit(human_present, 1'b0, "stable low after threshold");

        set_pir(1'b1);
        wait_cycles(2);
        set_pir(1'b0);
        wait_cycles(8);
        check_bit(human_present, 1'b0, "short high glitch ignored");

        if (errors == 0) begin
            $display("PASS all pir_human_detector tests");
        end else begin
            $display("FAIL %0d pir_human_detector tests", errors);
        end

        $finish;
    end

endmodule
