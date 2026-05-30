`timescale 1ns / 1ps

// pir_human_detector 的行为仿真测试平台。
// 使用 SIM_FAST 缩短预热和稳定计数时间，覆盖预热屏蔽、稳定高/低电平更新、
// 以及短暂毛刺被忽略等关键场景。
module tb_pir_human_detector;

    reg clk;
    reg rst_n;
    reg pir_in;

    wire pir_raw_sync;
    wire pir_valid;
    wire human_present;
    wire ir_active;

    integer errors;
    integer timeout_count;

    // 待测模块例化，保持真实参数接口，但启用 SIM_FAST 加速测试。
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
        .human_present(human_present),
        .ir_active(ir_active)
    );

    // 100 MHz 仿真时钟，周期 10 ns。
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 单比特断言辅助任务：比较实际值与期望值，并累计错误数。
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

    // 在时钟下降沿改变 PIR 输入，避免与待测模块采样沿竞争。
    task set_pir;
        input value;
        begin
            @(negedge clk);
            pir_in = value;
        end
    endtask

    // 等待指定数量的时钟周期，用于推动预热和稳定计数。
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // 主测试流程：复位、预热阶段检查、有效阶段高低电平稳定检查和毛刺过滤检查。
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

        // ir_active 测试：窗口逻辑和超时重触发。
        // 前面的测试已经多次触发 human_present 上升沿，ir_active 此时应为 1。
        check_bit(ir_active, 1'b1, "ir_active=1 (triggered by previous tests)");

        // 1. 保持电平不变，等待窗口超时，ir_active 应变为 0
        wait_cycles(210); // > 200 = INACTIVE_WINDOW_CYCLES_FAST in SIM_FAST
        check_bit(ir_active, 1'b0, "ir_active=0 after window expiry");

        // 2. 重新触发，ir_active 应再次变为 1
        set_pir(1'b0);
        wait_cycles(10);
        set_pir(1'b1);
        wait_cycles(10);
        check_bit(ir_active, 1'b1, "ir_active=1 after expiry re-trigger");

        // 3. 再次等待窗口超时，ir_active 应变为 0
        wait_cycles(210);
        check_bit(ir_active, 1'b0, "ir_active=0 after second window expiry");

        if (errors == 0) begin
            $display("PASS all pir_human_detector tests");
        end else begin
            $display("FAIL %0d pir_human_detector tests", errors);
        end

        $finish;
    end

endmodule
