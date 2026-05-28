`timescale 1ns / 1ps

module tb_health_lcd_top;

    reg clk;
    reg rst_n;
    reg pressure_ok;
    reg ir_ok;
    reg sim_fast;
    reg ultrasonic_front_echo;
    reg ultrasonic_left45_echo;
    reg ultrasonic_right45_echo;
    reg [15:0] weight_left_front;
    reg [15:0] weight_left_rear;
    reg [15:0] weight_right_front;
    reg [15:0] weight_right_rear;

    wire lcd_cs_n;
    wire lcd_rst_n;
    wire lcd_dc;
    wire lcd_scl;
    wire lcd_mosi;
    wire lcd_blk;
    wire ultrasonic_front_trig;
    wire ultrasonic_left45_trig;
    wire ultrasonic_right45_trig;
    wire [16:0] weight_front_back_diff;
    wire [16:0] weight_left_right_diff;
    wire [1:0] weight_front_back_balance;
    wire [1:0] weight_left_right_balance;

    integer errors;
    integer timeout_count;

    localparam [2:0] ST_IDLE           = 3'd0;
    localparam [2:0] ST_STUDY          = 3'd1;
    localparam [2:0] ST_SEDENTARY      = 3'd2;
    localparam [2:0] ST_OVER_SEDENTARY = 3'd3;
    localparam [2:0] ST_REST           = 3'd4;
    localparam [2:0] ST_AWAY_LONG      = 3'd5;

    health_lcd_top #(
        .CLK_HZ(1000),
        .SPI_CLK_DIV(1),
        .FRAME_HZ(2),
        .INIT_YEAR(2026),
        .INIT_MONTH(5),
        .INIT_DAY(14),
        .INIT_HOUR(8),
        .INIT_MIN(0),
        .INIT_SEC(0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pressure_ok(pressure_ok),
        .ir_ok(ir_ok),
        .ultrasonic_front_echo(ultrasonic_front_echo),
        .ultrasonic_left45_echo(ultrasonic_left45_echo),
        .ultrasonic_right45_echo(ultrasonic_right45_echo),
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .sim_fast(sim_fast),
        .ultrasonic_front_trig(ultrasonic_front_trig),
        .ultrasonic_left45_trig(ultrasonic_left45_trig),
        .ultrasonic_right45_trig(ultrasonic_right45_trig),
        .weight_front_back_diff(weight_front_back_diff),
        .weight_left_right_diff(weight_left_right_diff),
        .weight_front_back_balance(weight_front_back_balance),
        .weight_left_right_balance(weight_left_right_balance),
        .lcd_cs_n(lcd_cs_n),
        .lcd_rst_n(lcd_rst_n),
        .lcd_dc(lcd_dc),
        .lcd_scl(lcd_scl),
        .lcd_mosi(lcd_mosi),
        .lcd_blk(lcd_blk)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task wait_sim_minutes;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge dut.tick_1hz);
                repeat (3) @(posedge clk);
            end
        end
    endtask

    task check_state;
        input [2:0] expected;
        input [511:0] name;
        begin
            if (dut.seat_state !== expected) begin
                $display("FAIL state %0s: expected %0d got %0d at %0t", name, expected, dut.seat_state, $time);
                errors = errors + 1;
            end else begin
                $display("PASS state %0s at %0t", name, $time);
            end
        end
    endtask

    task check_hp;
        input [7:0] expected;
        input [511:0] name;
        begin
            if (dut.hp_value !== expected) begin
                $display("FAIL hp %0s: expected %0d got %0d at %0t", name, expected, dut.hp_value, $time);
                errors = errors + 1;
            end else begin
                $display("PASS hp %0s = %0d at %0t", name, dut.hp_value, $time);
            end
        end
    endtask

    task check_sit_time;
        input [15:0] expected;
        input [511:0] name;
        begin
            if (dut.sit_time_min !== expected) begin
                $display("FAIL sit_time %0s: expected %0d got %0d at %0t", name, expected, dut.sit_time_min, $time);
                errors = errors + 1;
            end else begin
                $display("PASS sit_time %0s = %0d at %0t", name, dut.sit_time_min, $time);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        pressure_ok = 1'b0;
        ir_ok = 1'b0;
        sim_fast = 1'b1;
        ultrasonic_front_echo = 1'b0;
        ultrasonic_left45_echo = 1'b0;
        ultrasonic_right45_echo = 1'b0;
        weight_left_front = 16'd0;
        weight_left_rear = 16'd0;
        weight_right_front = 16'd0;
        weight_right_rear = 16'd0;

        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        force dut.ultrasonic_front_distance_cm = 16'd40;
        force dut.ultrasonic_left45_distance_cm = 16'd27;
        force dut.ultrasonic_right45_distance_cm = 16'd27;

        timeout_count = 0;
        while ((dut.init_done != 1'b1) && (timeout_count < 10000)) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end

        if (dut.init_done == 1'b1) begin
            $display("PASS LCD init_done at %0t", $time);
        end else begin
            $display("FAIL LCD init_done timeout at %0t", $time);
            errors = errors + 1;
        end

        if (lcd_blk !== 1'b1) begin
            $display("FAIL lcd_blk should be high");
            errors = errors + 1;
        end

        pressure_ok = 1'b1;
        ir_ok = 1'b1;

        force dut.ultrasonic_front_distance_cm = 16'd40;
        wait_sim_minutes(1);
        check_hp(8'd100, "safe saturates at 100");

        force dut.ultrasonic_front_distance_cm = 16'd24;
        wait_sim_minutes(1);
        check_hp(8'd99, "warn minus one");

        force dut.ultrasonic_front_distance_cm = 16'd18;
        wait_sim_minutes(1);
        check_hp(8'd96, "danger minus three");

        wait_sim_minutes(32);
        check_hp(8'd0, "danger saturates at zero");
        if (dut.hp_zero_alarm !== 1'b1) begin
            $display("FAIL hp_zero_alarm expected high at %0t", $time);
            errors = errors + 1;
        end

        force dut.ultrasonic_front_distance_cm = 16'd40;
        wait_sim_minutes(10);
        check_state(ST_SEDENTARY, "45min sedentary");

        wait_sim_minutes(15);
        check_state(ST_OVER_SEDENTARY, "60min over sedentary");

        pressure_ok = 1'b0;
        ir_ok = 1'b0;
        wait_sim_minutes(20);
        check_state(ST_AWAY_LONG, "away 20min");

        wait_sim_minutes(10);
        check_state(ST_IDLE, "away 30min idle");

        if (dut.sit_time_min !== 16'd0) begin
            $display("FAIL sit_time_min should clear at away 30min, got %0d", dut.sit_time_min);
            errors = errors + 1;
        end
        check_hp(8'd100, "refills after idle");

        pressure_ok = 1'b1;
        ir_ok = 1'b1;
        wait_sim_minutes(5);
        check_sit_time(16'd5, "after fresh 5min study");

        pressure_ok = 1'b0;
        ir_ok = 1'b0;
        wait_sim_minutes(3);
        check_state(ST_REST, "away 3min rest");

        pressure_ok = 1'b1;
        ir_ok = 1'b1;
        wait_sim_minutes(1);
        check_sit_time(16'd6, "return within 3min keeps timer");

        pressure_ok = 1'b0;
        ir_ok = 1'b0;
        wait_sim_minutes(4);

        pressure_ok = 1'b1;
        ir_ok = 1'b1;
        repeat (3) @(posedge clk);
        check_sit_time(16'd0, "return after more than 3min clears timer");
        check_state(ST_STUDY, "valid rest restarts study");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d errors", errors);

        $finish;
    end

endmodule
