`timescale 1ns / 1ps

module weight_balance_analyzer #(
    parameter [15:0] WARN_DIFF = 16'd1000,
    parameter [15:0] DANGER_DIFF = 16'd3000
)(
    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_right_rear,
    output reg  [16:0] front_weight_sum,
    output reg  [16:0] rear_weight_sum,
    output reg  [16:0] left_weight_sum,
    output reg  [16:0] right_weight_sum,
    output reg  [16:0] front_back_diff,
    output reg  [16:0] left_right_diff,
    output reg  [1:0]  front_back_balance,
    output reg  [1:0]  left_right_balance
);

    localparam [1:0] BAL_CENTER = 2'd0;
    localparam [1:0] BAL_WARN   = 2'd1;
    localparam [1:0] BAL_DANGER = 2'd2;

    always @(*) begin
        front_weight_sum = {1'b0, weight_left_front} + {1'b0, weight_right_front};
        rear_weight_sum  = {1'b0, weight_left_rear} + {1'b0, weight_right_rear};
        left_weight_sum  = {1'b0, weight_left_front} + {1'b0, weight_left_rear};
        right_weight_sum = {1'b0, weight_right_front} + {1'b0, weight_right_rear};

        if (front_weight_sum >= rear_weight_sum)
            front_back_diff = front_weight_sum - rear_weight_sum;
        else
            front_back_diff = rear_weight_sum - front_weight_sum;

        if (left_weight_sum >= right_weight_sum)
            left_right_diff = left_weight_sum - right_weight_sum;
        else
            left_right_diff = right_weight_sum - left_weight_sum;

        if (front_back_diff >= {1'b0, DANGER_DIFF})
            front_back_balance = BAL_DANGER;
        else if (front_back_diff >= {1'b0, WARN_DIFF})
            front_back_balance = BAL_WARN;
        else
            front_back_balance = BAL_CENTER;

        if (left_right_diff >= {1'b0, DANGER_DIFF})
            left_right_balance = BAL_DANGER;
        else if (left_right_diff >= {1'b0, WARN_DIFF})
            left_right_balance = BAL_WARN;
        else
            left_right_balance = BAL_CENTER;
    end

endmodule
