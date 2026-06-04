`timescale 1ns / 1ps

module tb_weight_packet_link;

    reg clk;
    reg reset;
    reg [15:0] weight_left_front;
    reg [15:0] weight_right_front;
    reg [15:0] weight_left_rear;
    reg [15:0] weight_right_rear;
    reg seat_present;
    reg [1:0] left_right_state;
    reg [1:0] front_back_state;
    reg lean_left;
    reg lean_right;
    reg lean_front;
    reg lean_back;

    wire uart_link;
    wire packet_valid;
    wire [7:0] packet_seq;
    wire pressure_ok_rx;
    wire [15:0] weight_left_front_rx;
    wire [15:0] weight_right_front_rx;
    wire [15:0] weight_left_rear_rx;
    wire [15:0] weight_right_rear_rx;
    wire [1:0] left_right_state_rx;
    wire [1:0] front_back_state_rx;
    wire lean_left_rx;
    wire lean_right_rx;
    wire lean_front_rx;
    wire lean_back_rx;
    wire checksum_error;

    integer errors;
    integer timeout_count;

    weight_packet_tx #(
        .CLK_FREQ_HZ(1_000_000),
        .BAUD_RATE(100_000),
        .SEND_HZ(100)
    ) u_tx (
        .clk(clk),
        .reset(reset),
        .weight_left_front(weight_left_front),
        .weight_right_front(weight_right_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_rear(weight_right_rear),
        .seat_present(seat_present),
        .left_right_state(left_right_state),
        .front_back_state(front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .uart_tx(uart_link)
    );

    weight_packet_rx #(
        .CLK_FREQ_HZ(1_000_000),
        .BAUD_RATE(100_000)
    ) u_rx (
        .clk(clk),
        .reset(reset),
        .uart_rx_pin(uart_link),
        .packet_valid(packet_valid),
        .packet_seq(packet_seq),
        .pressure_ok(pressure_ok_rx),
        .weight_left_front(weight_left_front_rx),
        .weight_right_front(weight_right_front_rx),
        .weight_left_rear(weight_left_rear_rx),
        .weight_right_rear(weight_right_rear_rx),
        .left_right_state(left_right_state_rx),
        .front_back_state(front_back_state_rx),
        .lean_left(lean_left_rx),
        .lean_right(lean_right_rx),
        .lean_front(lean_front_rx),
        .lean_back(lean_back_rx),
        .checksum_error(checksum_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check16;
        input [15:0] actual;
        input [15:0] expected;
        input [255:0] name;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s: expected %0d got %0d", name, expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b1;
        weight_left_front = 16'd1000;
        weight_right_front = 16'd1100;
        weight_left_rear = 16'd1200;
        weight_right_rear = 16'd1300;
        seat_present = 1'b1;
        left_right_state = 2'd1;
        front_back_state = 2'd2;
        lean_left = 1'b0;
        lean_right = 1'b1;
        lean_front = 1'b0;
        lean_back = 1'b1;

        repeat (10) @(posedge clk);
        reset = 1'b0;

        timeout_count = 0;
        while (!packet_valid && (timeout_count < 30000)) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end

        if (!packet_valid) begin
            $display("FAIL packet_valid timeout");
            errors = errors + 1;
        end

        check16(weight_left_front_rx, weight_left_front, "left front");
        check16(weight_right_front_rx, weight_right_front, "right front");
        check16(weight_left_rear_rx, weight_left_rear, "left rear");
        check16(weight_right_rear_rx, weight_right_rear, "right rear");

        if (pressure_ok_rx !== seat_present) errors = errors + 1;
        if (left_right_state_rx !== left_right_state) errors = errors + 1;
        if (front_back_state_rx !== front_back_state) errors = errors + 1;
        if (lean_left_rx !== lean_left) errors = errors + 1;
        if (lean_right_rx !== lean_right) errors = errors + 1;
        if (lean_front_rx !== lean_front) errors = errors + 1;
        if (lean_back_rx !== lean_back) errors = errors + 1;
        if (checksum_error !== 1'b0) errors = errors + 1;

        if (errors == 0)
            $display("ALL WEIGHT LINK TESTS PASSED");
        else
            $display("WEIGHT LINK TESTS FAILED: %0d errors", errors);

        $finish;
    end

endmodule
