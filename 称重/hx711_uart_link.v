`timescale 1ns / 1ps

module hx711_uart_link #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115_200,
    parameter SCK_FREQ_HZ = 50_000,
    parameter GAIN_PULSES = 1
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        hx711_dout,
    output wire        hx711_sck,

    output wire        uart_tx,

    output wire [23:0] raw_data,
    output wire        raw_data_valid,
    output wire        link_busy
);

    localparam integer FRAME_LEN = 14;
    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_SEND = 2'd1;
    localparam [1:0] ST_WAIT = 2'd2;

    wire hx711_ready;
    wire hx711_busy;
    wire uart_busy;
    wire uart_done;

    reg [1:0] state;
    reg [3:0] frame_index;
    reg [23:0] frame_data;
    reg [23:0] pending_data;
    reg pending_valid;
    reg [7:0] uart_data;
    reg uart_start;

    assign link_busy = hx711_busy | uart_busy | pending_valid | (state != ST_IDLE);

    hx711_reader #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .SCK_FREQ_HZ(SCK_FREQ_HZ),
        .GAIN_PULSES(GAIN_PULSES)
    ) u_hx711_reader (
        .clk(clk),
        .rst_n(rst_n),
        .hx711_dout(hx711_dout),
        .hx711_sck(hx711_sck),
        .raw_data(raw_data),
        .raw_data_valid(raw_data_valid),
        .hx711_ready(hx711_ready),
        .busy(hx711_busy)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(uart_data),
        .tx_start(uart_start),
        .tx(uart_tx),
        .busy(uart_busy),
        .done(uart_done)
    );

    function [7:0] hex_char;
        input [3:0] nibble;
        begin
            if (nibble < 4'd10)
                hex_char = 8'h30 + nibble;
            else
                hex_char = 8'h41 + (nibble - 4'd10);
        end
    endfunction

    function [7:0] frame_char;
        input [3:0] index;
        input [23:0] value;
        begin
            case (index)
                4'd0:  frame_char = "R";
                4'd1:  frame_char = "A";
                4'd2:  frame_char = "W";
                4'd3:  frame_char = "=";
                4'd4:  frame_char = "0";
                4'd5:  frame_char = "x";
                4'd6:  frame_char = hex_char(value[23:20]);
                4'd7:  frame_char = hex_char(value[19:16]);
                4'd8:  frame_char = hex_char(value[15:12]);
                4'd9:  frame_char = hex_char(value[11:8]);
                4'd10: frame_char = hex_char(value[7:4]);
                4'd11: frame_char = hex_char(value[3:0]);
                4'd12: frame_char = 8'h0D;
                4'd13: frame_char = 8'h0A;
                default: frame_char = 8'h20;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            frame_index   <= 4'd0;
            frame_data    <= 24'd0;
            pending_data  <= 24'd0;
            pending_valid <= 1'b0;
            uart_data     <= 8'd0;
            uart_start    <= 1'b0;
        end else begin
            uart_start <= 1'b0;

            if (raw_data_valid) begin
                pending_data  <= raw_data;
                pending_valid <= 1'b1;
            end

            case (state)
                ST_IDLE: begin
                    frame_index <= 4'd0;

                    if (raw_data_valid) begin
                        frame_data    <= raw_data;
                        pending_valid <= 1'b0;
                        state         <= ST_SEND;
                    end else if (pending_valid) begin
                        frame_data    <= pending_data;
                        pending_valid <= 1'b0;
                        state         <= ST_SEND;
                    end
                end

                ST_SEND: begin
                    if (!uart_busy) begin
                        uart_data  <= frame_char(frame_index, frame_data);
                        uart_start <= 1'b1;
                        state      <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (uart_done) begin
                        if (frame_index == FRAME_LEN - 1) begin
                            frame_index <= 4'd0;
                            state       <= ST_IDLE;
                        end else begin
                            frame_index <= frame_index + 1'b1;
                            state       <= ST_SEND;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
