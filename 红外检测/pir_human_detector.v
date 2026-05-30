`timescale 1ns / 1ps

// PIR 红外人体存在检测模块。
// 负责完成传感器上电预热、异步输入同步、稳定时间滤波，
// 输出“检测结果是否可信”（pir_valid）、“当前电平是否有人”（human_present），
// 以及基于时间窗口的“是否有人活动”（ir_active）。
//
// ir_active 策略说明：
//   PIR 传感器本质上是运动检测器（检测红外变化），不能检测静止人体。
//   因此不能仅靠 human_present 的当前电平值来判断是否有人。
//   本模块统计 human_present 的上升沿（即人体运动触发事件总数），
//   在 INACTIVE_WINDOW_SEC 秒的时间窗口内：
//     - 至少发生一次触发 → ir_active = 1（判断有人活动）
//     - 没有任何触发       → ir_active = 0（判定无人，否决入座）
//   预热完成前 ir_active 强制为 0。
module pir_human_detector #(
    parameter CLK_FREQ_HZ             = 100_000_000,
    parameter WARMUP_SEC              = 60,
    parameter STABLE_MS               = 100,
    parameter SIM_FAST                = 0,
    parameter INACTIVE_WINDOW_SEC     = 180, // 无触发窗口时间（秒），默认 3 分钟
    parameter INACTIVE_WINDOW_CYCLES_FAST = 200 // 仿真快速模式下窗口周期数
)(
    input  wire clk,
    input  wire rst_n,
    input  wire pir_in,

    output wire pir_raw_sync,
    output reg  pir_valid,
    output reg  human_present,
    output reg  ir_active       // 时间窗口内的红外活动标志（1=有人活动）
);

    // 计算计数器所需位宽。
    // Verilog 兼容写法，避免依赖 SystemVerilog 的 $clog2。
    function integer clog2;
        input [63:0] value;
        reg [63:0] v;
        integer r;
        begin
            v = value - 64'd1;
            for (r = 0; v > 0; r = r + 1)
                v = v >> 1;

            if (r < 1)
                clog2 = 1;
            else
                clog2 = r;
        end
    endfunction

    localparam [63:0] WARMUP_CYCLES_RAW =
        (SIM_FAST != 0) ? 64'd20 : (64'd1 * CLK_FREQ_HZ * WARMUP_SEC);
    localparam [63:0] STABLE_CYCLES_RAW =
        (SIM_FAST != 0) ? 64'd5 : (64'd1 * (CLK_FREQ_HZ / 1000) * STABLE_MS);

    localparam [63:0] WARMUP_CYCLES =
        (WARMUP_CYCLES_RAW < 64'd1) ? 64'd1 : WARMUP_CYCLES_RAW;
    localparam [63:0] STABLE_CYCLES =
        (STABLE_CYCLES_RAW < 64'd1) ? 64'd1 : STABLE_CYCLES_RAW;

    localparam integer WARMUP_CNT_W = clog2(WARMUP_CYCLES);
    localparam integer STABLE_CNT_W = clog2(STABLE_CYCLES + 64'd1);

    // 无触发窗口周期数计算。
    // 仿真快速模式：使用 INACTIVE_WINDOW_CYCLES_FAST 个周期（短计数，加速仿真）。
    // 实际运行模式：使用 CLK_FREQ_HZ * INACTIVE_WINDOW_SEC 个周期。
    localparam [63:0] WINDOW_CYCLES_RAW =
        (SIM_FAST != 0) ? INACTIVE_WINDOW_CYCLES_FAST : (64'd1 * CLK_FREQ_HZ * INACTIVE_WINDOW_SEC);
    localparam [63:0] WINDOW_CYCLES =
        (WINDOW_CYCLES_RAW < 64'd1) ? 64'd1 : WINDOW_CYCLES_RAW;
    localparam integer WINDOW_CNT_W = clog2(WINDOW_CYCLES);

    // pir_meta/pir_sync 构成两级同步器；后面的计数器分别用于预热期和输入稳定判定。
    reg pir_meta;
    reg pir_sync;

    reg [WARMUP_CNT_W-1:0] warmup_cnt;
    reg [STABLE_CNT_W-1:0] stable_cnt;
    reg stable_level;

    // 无触发窗口计数器，以及 human_present 上一拍值（用于上升沿检测）。
    reg [WINDOW_CNT_W-1:0] window_cnt;
    reg prev_human_present;

    assign pir_raw_sync = pir_sync;

    // 异步 PIR 输入同步到 clk 时钟域，降低亚稳态传播风险。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pir_meta <= 1'b0;
            pir_sync <= 1'b0;
        end else begin
            pir_meta <= pir_in;
            pir_sync <= pir_meta;
        end
    end

    // 预热与稳定滤波主逻辑。
    // 预热完成前强制 human_present 为 0；预热后只有输入电平持续 STABLE_MS
    // 才更新 human_present，从而过滤红外模块的短脉冲抖动。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warmup_cnt   <= {WARMUP_CNT_W{1'b0}};
            stable_cnt   <= {STABLE_CNT_W{1'b0}};
            stable_level <= 1'b0;
            pir_valid    <= 1'b0;
            human_present <= 1'b0;
        end else begin
            if (!pir_valid) begin
                human_present <= 1'b0;
                stable_level  <= pir_sync;
                stable_cnt    <= {STABLE_CNT_W{1'b0}};

                if (warmup_cnt == WARMUP_CYCLES - 64'd1) begin
                    warmup_cnt <= {WARMUP_CNT_W{1'b0}};
                    pir_valid  <= 1'b1;
                end else begin
                    warmup_cnt <= warmup_cnt + 1'b1;
                end
            end else begin
                if (pir_sync != stable_level) begin
                    stable_level <= pir_sync;

                    if (STABLE_CYCLES == 64'd1) begin
                        stable_cnt    <= STABLE_CYCLES;
                        human_present <= pir_sync;
                    end else begin
                        stable_cnt <= 1'b1;
                    end
                end else if (stable_cnt < STABLE_CYCLES) begin
                    stable_cnt <= stable_cnt + 1'b1;

                    if (stable_cnt == STABLE_CYCLES - 64'd1)
                        human_present <= stable_level;
                end
            end
        end
    end

    // 无触发窗口与 ir_active 逻辑。
    // 目的：PIR 是运动传感器（检测红外变化），不能仅靠单次 human_present
    // 值判断是否有人。此处统计 human_present 的上升沿（即人体运动触发事件）。
    // 如果在 INACTIVE_WINDOW_SEC 秒的时间窗口内至少发生一次触发：
    //   ir_active = 1（判断有人活动）。
    // 如果窗口内没有任何触发事件：
    //   ir_active = 0（判定无人，具备否决入座的权力）。
    //
    // 预热完成前 ir_active 强制为 0，窗口计数器不推进。
    // 预热完成后，每次 human_present 上升沿将窗口计数器清零并置 ir_active=1。
    // 计数器累加到 WINDOW_CYCLES 时，ir_active 清零（窗口到期，无人活动）。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ir_active          <= 1'b0;
            window_cnt         <= {WINDOW_CNT_W{1'b0}};
            prev_human_present <= 1'b0;
        end else begin
            prev_human_present <= human_present;

            if (!pir_valid) begin
                // 预热期间，窗口计数器保持清零，ir_active 保持 0
                ir_active  <= 1'b0;
                window_cnt <= {WINDOW_CNT_W{1'b0}};
            end else begin
                // 检测 human_present 上升沿（表示一次人体运动触发事件）
                if (human_present && !prev_human_present) begin
                    // 检测到触发 — 重置窗口，ir_active 置 1
                    window_cnt <= {WINDOW_CNT_W{1'b0}};
                    ir_active  <= 1'b1;
                end else if (window_cnt < WINDOW_CYCLES) begin
                    // 窗口尚未到期，继续计数
                    window_cnt <= window_cnt + 1'b1;
                end else begin
                    // 窗口到期 — 无新的触发事件，判定无人
                    ir_active <= 1'b0;
                end
            end
        end
    end

endmodule
