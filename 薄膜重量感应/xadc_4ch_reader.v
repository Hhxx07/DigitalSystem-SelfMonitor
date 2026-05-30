// 四通道 XADC 压力采样读取模块。
// 连接 FPGA 内部 XADC 原语，轮询 VAUX0/2/3/8 四路薄膜压力传感器，
// 对每一路做 16 次累加平均后输出 12 位压力值。
module xadc_4ch_reader (
    input  wire       clk,
    input  wire       reset,

    input  wire       vauxp0,
    input  wire       vauxn0,
    input  wire       vauxp2,
    input  wire       vauxn2,
    input  wire       vauxp3,
    input  wire       vauxn3,
    input  wire       vauxp8,
    input  wire       vauxn8,

    output reg [11:0] pressure0,
    output reg [11:0] pressure2,
    output reg [11:0] pressure3,
    output reg [11:0] pressure8,
    output reg        sample_update
);

    wire [15:0] do_out;
    wire [4:0]  channel;
    wire        drdy;
    wire        eoc;
    wire        eos;
    wire        busy;
    wire [7:0]  alarm;
    wire        ot;
    wire        jtagbusy;
    wire        jtaglocked;
    wire        jtagmodified;

    reg [4:0] read_channel;

    // 各通道独立累加器和样本计数器，用于降低 ADC 抖动。
    reg [15:0] sum0;
    reg [15:0] sum2;
    reg [15:0] sum3;
    reg [15:0] sum8;
    reg [3:0] count0;
    reg [3:0] count2;
    reg [3:0] count3;
    reg [3:0] count8;

    wire [11:0] pressure_sample;
    // XADC 原始码为电压正相关，这里反相成“压力越大数值越大”的表示。
    assign pressure_sample = 12'hfff - do_out[15:4];

    wire [15:0] vauxp;
    wire [15:0] vauxn;

    // 将实际使用的四个外部模拟通道接入 XADC 的 16 位 VAUX 总线，其余通道固定为 0。
    assign vauxp[0]  = vauxp0;
    assign vauxn[0]  = vauxn0;
    assign vauxp[1]  = 1'b0;
    assign vauxn[1]  = 1'b0;
    assign vauxp[2]  = vauxp2;
    assign vauxn[2]  = vauxn2;
    assign vauxp[3]  = vauxp3;
    assign vauxn[3]  = vauxn3;
    assign vauxp[4]  = 1'b0;
    assign vauxn[4]  = 1'b0;
    assign vauxp[5]  = 1'b0;
    assign vauxn[5]  = 1'b0;
    assign vauxp[6]  = 1'b0;
    assign vauxn[6]  = 1'b0;
    assign vauxp[7]  = 1'b0;
    assign vauxn[7]  = 1'b0;
    assign vauxp[8]  = vauxp8;
    assign vauxn[8]  = vauxn8;
    assign vauxp[9]  = 1'b0;
    assign vauxn[9]  = 1'b0;
    assign vauxp[10] = 1'b0;
    assign vauxn[10] = 1'b0;
    assign vauxp[11] = 1'b0;
    assign vauxn[11] = 1'b0;
    assign vauxp[12] = 1'b0;
    assign vauxn[12] = 1'b0;
    assign vauxp[13] = 1'b0;
    assign vauxn[13] = 1'b0;
    assign vauxp[14] = 1'b0;
    assign vauxn[14] = 1'b0;
    assign vauxp[15] = 1'b0;
    assign vauxn[15] = 1'b0;

    // XADC 数据接收与滑动分组平均。
    // eoc 表示一次转换结束并给出当前通道号；drdy 表示 DO 数据有效。
    // 每个目标通道收满 16 个样本后右移 4 位求平均，并产生 sample_update 脉冲。
    always @(posedge clk) begin
        if (reset) begin
            read_channel <= 5'd0;
            pressure0 <= 12'd0;
            pressure2 <= 12'd0;
            pressure3 <= 12'd0;
            pressure8 <= 12'd0;
            sum0 <= 16'd0;
            sum2 <= 16'd0;
            sum3 <= 16'd0;
            sum8 <= 16'd0;
            count0 <= 4'd0;
            count2 <= 4'd0;
            count3 <= 4'd0;
            count8 <= 4'd0;
            sample_update <= 1'b0;
        end else begin
            sample_update <= 1'b0;

            if (eoc) begin
                read_channel <= channel;
            end

            if (drdy) begin
                case (read_channel)
                    5'h10: begin
                        if (count0 == 4'd15) begin
                            pressure0 <= (sum0 + pressure_sample) >> 4;
                            sum0 <= 16'd0;
                            count0 <= 4'd0;
                            sample_update <= 1'b1;
                        end else begin
                            sum0 <= sum0 + pressure_sample;
                            count0 <= count0 + 4'd1;
                        end
                    end

                    5'h12: begin
                        if (count2 == 4'd15) begin
                            pressure2 <= (sum2 + pressure_sample) >> 4;
                            sum2 <= 16'd0;
                            count2 <= 4'd0;
                            sample_update <= 1'b1;
                        end else begin
                            sum2 <= sum2 + pressure_sample;
                            count2 <= count2 + 4'd1;
                        end
                    end

                    5'h13: begin
                        if (count3 == 4'd15) begin
                            pressure3 <= (sum3 + pressure_sample) >> 4;
                            sum3 <= 16'd0;
                            count3 <= 4'd0;
                            sample_update <= 1'b1;
                        end else begin
                            sum3 <= sum3 + pressure_sample;
                            count3 <= count3 + 4'd1;
                        end
                    end

                    5'h18: begin
                        if (count8 == 4'd15) begin
                            pressure8 <= (sum8 + pressure_sample) >> 4;
                            sum8 <= 16'd0;
                            count8 <= 4'd0;
                            sample_update <= 1'b1;
                        end else begin
                            sum8 <= sum8 + pressure_sample;
                            count8 <= count8 + 4'd1;
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    // Xilinx 7 系列 XADC 原语配置。
    // 采用连续扫描模式，打开 VAUX0/2/3/8，读地址跟随当前转换通道。
    XADC #(
        .INIT_40(16'h0000),
        .INIT_41(16'h2000),
        .INIT_42(16'h0400),
        .INIT_48(16'h0000),
        .INIT_49(16'h010D),
        .INIT_4A(16'h0000),
        .INIT_4B(16'h0000),
        .INIT_4C(16'h0000),
        .INIT_4D(16'h0000),
        .INIT_4E(16'h0000),
        .INIT_4F(16'h0000),
        .SIM_DEVICE("7SERIES")
    ) xadc_inst (
        .DADDR({2'b00, channel}),
        .DCLK(clk),
        .DEN(eoc),
        .DI(16'd0),
        .DWE(1'b0),
        .RESET(reset),
        .VAUXN(vauxn),
        .VAUXP(vauxp),
        .VN(1'b0),
        .VP(1'b0),
        .ALM(alarm),
        .BUSY(busy),
        .CHANNEL(channel),
        .DO(do_out),
        .DRDY(drdy),
        .EOC(eoc),
        .EOS(eos),
        .JTAGBUSY(jtagbusy),
        .JTAGLOCKED(jtaglocked),
        .JTAGMODIFIED(jtagmodified),
        .OT(ot),
        .CONVST(1'b0),
        .CONVSTCLK(1'b0)
    );

endmodule
