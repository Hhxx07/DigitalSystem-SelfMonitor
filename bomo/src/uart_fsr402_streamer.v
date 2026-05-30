module uart_fsr402_streamer #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200,
    parameter integer REPORT_HZ   = 5
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [11:0] pressure_fl,
    input  wire [11:0] pressure_fr,
    input  wire [11:0] pressure_bl,
    input  wire [11:0] pressure_br,
    output wire        uart_tx
);

    localparam integer REPORT_DIV = CLK_FREQ_HZ / REPORT_HZ;
    localparam integer LINE_LEN = 33;

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_SEND = 2'd1;
    localparam [1:0] S_WAIT = 2'd2;

    reg [31:0] report_count;
    reg [1:0] state;
    reg [5:0] byte_index;

    reg [11:0] fl_latch;
    reg [11:0] fr_latch;
    reg [11:0] bl_latch;
    reg [11:0] br_latch;

    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    wire tx_done;

    wire [31:0] fl_ascii;
    wire [31:0] fr_ascii;
    wire [31:0] bl_ascii;
    wire [31:0] br_ascii;

    assign fl_ascii = dec4_ascii(fl_latch);
    assign fr_ascii = dec4_ascii(fr_latch);
    assign bl_ascii = dec4_ascii(bl_latch);
    assign br_ascii = dec4_ascii(br_latch);

    function [31:0] dec4_ascii;
        input [11:0] value;
        reg [11:0] rem0;
        reg [11:0] rem1;
        reg [11:0] rem2;
        reg [3:0] thousands;
        reg [3:0] hundreds;
        reg [3:0] tens;
        reg [3:0] ones;
        begin
            if (value >= 12'd4000) begin
                thousands = 4'd4;
                rem0 = value - 12'd4000;
            end else if (value >= 12'd3000) begin
                thousands = 4'd3;
                rem0 = value - 12'd3000;
            end else if (value >= 12'd2000) begin
                thousands = 4'd2;
                rem0 = value - 12'd2000;
            end else if (value >= 12'd1000) begin
                thousands = 4'd1;
                rem0 = value - 12'd1000;
            end else begin
                thousands = 4'd0;
                rem0 = value;
            end

            if (rem0 >= 12'd900) begin hundreds = 4'd9; rem1 = rem0 - 12'd900; end
            else if (rem0 >= 12'd800) begin hundreds = 4'd8; rem1 = rem0 - 12'd800; end
            else if (rem0 >= 12'd700) begin hundreds = 4'd7; rem1 = rem0 - 12'd700; end
            else if (rem0 >= 12'd600) begin hundreds = 4'd6; rem1 = rem0 - 12'd600; end
            else if (rem0 >= 12'd500) begin hundreds = 4'd5; rem1 = rem0 - 12'd500; end
            else if (rem0 >= 12'd400) begin hundreds = 4'd4; rem1 = rem0 - 12'd400; end
            else if (rem0 >= 12'd300) begin hundreds = 4'd3; rem1 = rem0 - 12'd300; end
            else if (rem0 >= 12'd200) begin hundreds = 4'd2; rem1 = rem0 - 12'd200; end
            else if (rem0 >= 12'd100) begin hundreds = 4'd1; rem1 = rem0 - 12'd100; end
            else begin hundreds = 4'd0; rem1 = rem0; end

            if (rem1 >= 12'd90) begin tens = 4'd9; rem2 = rem1 - 12'd90; end
            else if (rem1 >= 12'd80) begin tens = 4'd8; rem2 = rem1 - 12'd80; end
            else if (rem1 >= 12'd70) begin tens = 4'd7; rem2 = rem1 - 12'd70; end
            else if (rem1 >= 12'd60) begin tens = 4'd6; rem2 = rem1 - 12'd60; end
            else if (rem1 >= 12'd50) begin tens = 4'd5; rem2 = rem1 - 12'd50; end
            else if (rem1 >= 12'd40) begin tens = 4'd4; rem2 = rem1 - 12'd40; end
            else if (rem1 >= 12'd30) begin tens = 4'd3; rem2 = rem1 - 12'd30; end
            else if (rem1 >= 12'd20) begin tens = 4'd2; rem2 = rem1 - 12'd20; end
            else if (rem1 >= 12'd10) begin tens = 4'd1; rem2 = rem1 - 12'd10; end
            else begin tens = 4'd0; rem2 = rem1; end

            ones = rem2[3:0];
            dec4_ascii = {8'd48 + thousands, 8'd48 + hundreds, 8'd48 + tens, 8'd48 + ones};
        end
    endfunction

    function [7:0] line_byte;
        input [5:0] index;
        begin
            case (index)
                6'd0:  line_byte = "F";
                6'd1:  line_byte = "L";
                6'd2:  line_byte = "=";
                6'd3:  line_byte = fl_ascii[31:24];
                6'd4:  line_byte = fl_ascii[23:16];
                6'd5:  line_byte = fl_ascii[15:8];
                6'd6:  line_byte = fl_ascii[7:0];
                6'd7:  line_byte = " ";
                6'd8:  line_byte = "F";
                6'd9:  line_byte = "R";
                6'd10: line_byte = "=";
                6'd11: line_byte = fr_ascii[31:24];
                6'd12: line_byte = fr_ascii[23:16];
                6'd13: line_byte = fr_ascii[15:8];
                6'd14: line_byte = fr_ascii[7:0];
                6'd15: line_byte = " ";
                6'd16: line_byte = "B";
                6'd17: line_byte = "L";
                6'd18: line_byte = "=";
                6'd19: line_byte = bl_ascii[31:24];
                6'd20: line_byte = bl_ascii[23:16];
                6'd21: line_byte = bl_ascii[15:8];
                6'd22: line_byte = bl_ascii[7:0];
                6'd23: line_byte = " ";
                6'd24: line_byte = "B";
                6'd25: line_byte = "R";
                6'd26: line_byte = "=";
                6'd27: line_byte = br_ascii[31:24];
                6'd28: line_byte = br_ascii[23:16];
                6'd29: line_byte = br_ascii[15:8];
                6'd30: line_byte = br_ascii[7:0];
                6'd31: line_byte = 8'd13;
                6'd32: line_byte = 8'd10;
                default: line_byte = 8'd10;
            endcase
        end
    endfunction

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx),
        .busy(tx_busy),
        .done(tx_done)
    );

    always @(posedge clk) begin
        if (reset) begin
            report_count <= 32'd0;
            state <= S_IDLE;
            byte_index <= 6'd0;
            fl_latch <= 12'd0;
            fr_latch <= 12'd0;
            bl_latch <= 12'd0;
            br_latch <= 12'd0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            if (report_count == REPORT_DIV - 1) begin
                report_count <= 32'd0;
            end else begin
                report_count <= report_count + 32'd1;
            end

            case (state)
                S_IDLE: begin
                    if (report_count == REPORT_DIV - 1) begin
                        fl_latch <= pressure_fl;
                        fr_latch <= pressure_fr;
                        bl_latch <= pressure_bl;
                        br_latch <= pressure_br;
                        byte_index <= 6'd0;
                        state <= S_SEND;
                    end
                end

                S_SEND: begin
                    if (!tx_busy) begin
                        tx_data <= line_byte(byte_index);
                        tx_start <= 1'b1;
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (tx_done) begin
                        if (byte_index == LINE_LEN - 1) begin
                            state <= S_IDLE;
                        end else begin
                            byte_index <= byte_index + 6'd1;
                            state <= S_SEND;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
