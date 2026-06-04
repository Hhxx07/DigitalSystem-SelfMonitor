`timescale 1ns / 1ps

module weight_balance_analyzer #(
    parameter [7:0] WARN_PERCENT   = 8'd15,
    parameter [7:0] DANGER_PERCENT = 8'd30
) (
    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_right_rear,
    output wire [16:0] front_weight_sum,
    output wire [16:0] rear_weight_sum,
    output wire [16:0] left_weight_sum,
    output wire [16:0] right_weight_sum,
    output wire [16:0] front_back_diff,
    output wire [16:0] left_right_diff,
    output wire [1:0]  front_back_balance,
    output wire [1:0]  left_right_balance
);

    wire [17:0] total_sum;
    wire [24:0] front_back_percent;
    wire [24:0] left_right_percent;
    wire [25:0] warn_scaled;
    wire [25:0] danger_scaled;
    wire front_back_warn;
    wire front_back_danger;
    wire left_right_warn;
    wire left_right_danger;

    assign front_weight_sum = {1'b0, weight_left_front}  + {1'b0, weight_right_front};
    assign rear_weight_sum  = {1'b0, weight_left_rear}   + {1'b0, weight_right_rear};
    assign left_weight_sum  = {1'b0, weight_left_front}  + {1'b0, weight_left_rear};
    assign right_weight_sum = {1'b0, weight_right_front} + {1'b0, weight_right_rear};

    assign front_back_diff = (front_weight_sum >= rear_weight_sum) ?
                             (front_weight_sum - rear_weight_sum) :
                             (rear_weight_sum - front_weight_sum);

    assign left_right_diff = (left_weight_sum >= right_weight_sum) ?
                             (left_weight_sum - right_weight_sum) :
                             (right_weight_sum - left_weight_sum);

    assign total_sum = {1'b0, left_weight_sum} + {1'b0, right_weight_sum};

    assign front_back_percent = front_back_diff * 8'd100;
    assign left_right_percent = left_right_diff * 8'd100;
    assign warn_scaled = total_sum * WARN_PERCENT;
    assign danger_scaled = total_sum * DANGER_PERCENT;

    assign front_back_warn = (total_sum != 18'd0) && (front_back_percent >= warn_scaled);
    assign front_back_danger = (total_sum != 18'd0) && (front_back_percent >= danger_scaled);
    assign left_right_warn = (total_sum != 18'd0) && (left_right_percent >= warn_scaled);
    assign left_right_danger = (total_sum != 18'd0) && (left_right_percent >= danger_scaled);

    assign front_back_balance = front_back_danger ? 2'd2 : (front_back_warn ? 2'd1 : 2'd0);
    assign left_right_balance = left_right_danger ? 2'd2 : (left_right_warn ? 2'd1 : 2'd0);

endmodule
