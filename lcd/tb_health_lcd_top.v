`timescale 1ns / 1ps

// health_lcd_top 集成测试平台。
// 使用低 CLK_HZ、快速 SPI 和 sim_fast 缩短仿真时间，
// 覆盖 LCD 初始化、HP 增减、久坐状态、离座休息、计时清零、
// 以及三条件入座判断（IR活动窗口+超声波距离+压力）和IR否决等系统行为。
module tb_health_lcd_top;

    reg clk;
    reg rst_n;
    reg pressure_ok;
    reg pir_enable;     // 1=模拟PIR持续活动（产生翻转），0=PIR静止
    reg pir_in;         // PIR原始信号（由后台always块驱动）
    reg [7:0] pir_toggle_cnt;  // PIR翻转计数器（8位宽以支持慢速翻转）
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

    // 待测顶层例化。
    // 仿真中通过 force 固定超声波测距结果，避免等待真实 Echo 脉宽。
    health_lcd_top #(
        .CLK_HZ(1000),
        .SPI_CLK_DIV(1),
        .FRAME_HZ(2),
        .INIT_YEAR(2026),
        .INIT_MONTH(5),
        .INIT_DAY(14),
        .INIT_HOUR(8),
        .INIT_MIN(0),
        .INIT_SEC(0),
        .PIR_INACTIVE_WINDOW_SEC(5),  // 仿真窗口 5 秒，方便 IR 否决测试
        .PIR_WINDOW_CYCLES_FAST(50000)  // 大窗口确保跨多个sim_minutes
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pressure_ok(pressure_ok),
        .pir_in(pir_in),
        .ultrasonic_front_echo(ultrasonic_front_echo),
        .ultrasonic_left45_echo(ultrasonic_left45_echo),
        .ultrasonic_right45_echo(ultrasonic_right45_echo),
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .weight_left_right_state(2'd0),
        .weight_front_back_state(2'd0),
        .lean_left(1'b0),
        .lean_right(1'b0),
        .lean_front(1'b0),
        .lean_back(1'b0),
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

    // 100 MHz 测试时钟。
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // PIR 红外信号模拟：pir_enable=1 时每 200 个周期翻转 pir_in，
    // 使 human_present 有足够时间稳定（STABLE_CYCLES=100），
    // 从而产生上升沿保持 ir_active=1（窗口被持续重置）。
    // pir_enable=0 时 pir_in 保持为 0，ir_active 将在窗口到期后变 0。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pir_toggle_cnt <= 8'd0;
            pir_in <= 1'b0;
        end else if (pir_enable) begin
            pir_toggle_cnt <= pir_toggle_cnt + 8'd1;
            if (pir_toggle_cnt == 8'd199) begin
                pir_toggle_cnt <= 8'd0;
                pir_in <= ~pir_in;  // 每 200 个周期翻转一次
            end
        end else begin
            pir_toggle_cnt <= 8'd0;
            pir_in <= 1'b0;
        end
    end

    // 等待指定数量的仿真“分钟”。
    // sim_fast 下 seat_fsm/hp_engine 把每个 tick_1hz 当作一分钟处理。
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

    // 座椅状态断言辅助任务。
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

    // HP 数值断言辅助任务。
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

    // 入座计时断言辅助任务。
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

    // 主测试流程。
    // 依次验证初始化完成、不同距离下 HP 变化、45/60 分钟久坐阈值、
    // 离座 20/30 分钟状态、短休息保留计时和长休息清零。
    initial begin
        errors = 0;
        rst_n = 1'b0;
        pressure_ok = 1'b0;
        pir_enable =1'b0;
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
        pir_enable = 1'b1;

        // 仿真中通过 force 固定 ir_active 为 1，跳过 PIR 预热/翻转
        // 时序，直接进入入座状态测试。IR 否决测试时再释放 force。
        force dut.ir_active = 1'b1;
        $display("INFO: forcing ir_active=1 for HP/state tests at %0t", $time);

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
        pir_enable =1'b0;
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
        pir_enable =1'b1;
        wait_sim_minutes(5);
        check_sit_time(16'd5, "after fresh 5min study");

        pressure_ok = 1'b0;
        pir_enable =1'b0;
        wait_sim_minutes(3);
        check_state(ST_REST, "away 3min rest");

        pressure_ok = 1'b1;
        pir_enable =1'b1;
        wait_sim_minutes(1);
        check_sit_time(16'd6, "return within 3min keeps timer");

        pressure_ok = 1'b0;
        pir_enable =1'b0;
        wait_sim_minutes(4);

        pressure_ok = 1'b1;
        pir_enable =1'b1;
        repeat (3) @(posedge clk);
        check_sit_time(16'd0, "return after more than 3min clears timer");
        check_state(ST_STUDY, "valid rest restarts study");

        // IR 否决（inactivity veto）测试。
        // 释放 force，让 ir_active 由 PIR 模块的窗口逻辑正常控制。
        // 步骤：释放 force → 确认 seated=1 → 停止 PIR 活动 → 等待窗口到期 → 验证 seated=0
        release dut.ir_active;
        pressure_ok = 1'b1;
        pir_enable = 1'b1;  // 先确保 PIR 活动
        wait_sim_minutes(1);
        if (dut.seated !== 1'b1) begin
            $display("FAIL seated should be 1 when all three conditions met, got %0b at %0t", dut.seated, $time);
            errors = errors + 1;
        end else begin
            $display("PASS seated=1 before IR veto test at %0t", $time);
        end

        // 关闭 PIR 活动，等待 IR 无触发窗口到期
        pir_enable = 1'b0;
        // PIR_WINDOW_CYCLES_FAST=50000 个周期，CLK_HZ=1000，约 50 个 tick
        // 等待 60 个 tick 确保窗口必然到期
        wait_sim_minutes(60);
        if (dut.seated !== 1'b0) begin
            $display("FAIL seated should be 0 after IR window expiry, got %0b at %0t", dut.seated, $time);
            errors = errors + 1;
        end else begin
            $display("PASS seated=0 after IR veto (PIR window expired) at %0t", $time);
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d errors", errors);

        $finish;
    end

endmodule
