`timescale 1ns / 1ps

module seat_weight_analyzer #(
    parameter [15:0] SEAT_ON_TH        = 16'd800,
    parameter [15:0] SEAT_OFF_TH       = 16'd300,
    parameter [7:0]  WARN_PERCENT      = 8'd15,
    parameter [7:0]  DANGER_PERCENT    = 8'd30
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_rear,
    output reg         seat_present,
    output wire [16:0] left_sum,
    output wire [16:0] right_sum,
    output wire [16:0] front_sum,
    output wire [16:0] rear_sum,
    output wire [16:0] left_right_diff,
    output wire [16:0] front_back_diff,
    output wire [1:0]  left_right_state,
    output wire [1:0]  front_back_state,
    output wire        lean_left,
    output wire        lean_right,
    output wire        lean_front,
    output wire        lean_back
);

    wire any_on;
    wire all_off;
    wire [17:0] total_sum;
    wire [24:0] lr_diff_percent;
    wire [24:0] fb_diff_percent;
    wire [25:0] warn_scaled;
    wire [25:0] danger_scaled;
    wire lr_warn;
    wire lr_danger;
    wire fb_warn;
    wire fb_danger;

    assign any_on = (weight_left_front  > SEAT_ON_TH)  ||
                    (weight_right_front > SEAT_ON_TH)  ||
                    (weight_left_rear   > SEAT_ON_TH)  ||
                    (weight_right_rear  > SEAT_ON_TH);

    assign all_off = (weight_left_front  < SEAT_OFF_TH) &&
                     (weight_right_front < SEAT_OFF_TH) &&
                     (weight_left_rear   < SEAT_OFF_TH) &&
                     (weight_right_rear  < SEAT_OFF_TH);

    assign left_sum  = {1'b0, weight_left_front}  + {1'b0, weight_left_rear};
    assign right_sum = {1'b0, weight_right_front} + {1'b0, weight_right_rear};
    assign front_sum = {1'b0, weight_left_front}  + {1'b0, weight_right_front};
    assign rear_sum  = {1'b0, weight_left_rear}   + {1'b0, weight_right_rear};

    assign left_right_diff = (left_sum >= right_sum) ? (left_sum - right_sum) : (right_sum - left_sum);
    assign front_back_diff = (front_sum >= rear_sum) ? (front_sum - rear_sum) : (rear_sum - front_sum);
    assign total_sum = {1'b0, left_sum} + {1'b0, right_sum};

    assign lr_diff_percent = left_right_diff * 8'd100;
    assign fb_diff_percent = front_back_diff * 8'd100;
    assign warn_scaled = total_sum * WARN_PERCENT;
    assign danger_scaled = total_sum * DANGER_PERCENT;

    assign lr_warn = seat_present && (total_sum != 18'd0) && (lr_diff_percent >= warn_scaled);
    assign lr_danger = seat_present && (total_sum != 18'd0) && (lr_diff_percent >= danger_scaled);
    assign fb_warn = seat_present && (total_sum != 18'd0) && (fb_diff_percent >= warn_scaled);
    assign fb_danger = seat_present && (total_sum != 18'd0) && (fb_diff_percent >= danger_scaled);

    assign left_right_state = lr_danger ? 2'd2 : (lr_warn ? 2'd1 : 2'd0);
    assign front_back_state = fb_danger ? 2'd2 : (fb_warn ? 2'd1 : 2'd0);

    assign lean_left  = lr_warn && (left_sum > right_sum);
    assign lean_right = lr_warn && (right_sum > left_sum);
    assign lean_front = fb_warn && (front_sum > rear_sum);
    assign lean_back  = fb_warn && (rear_sum > front_sum);

    always @(posedge clk) begin
        if (reset) begin
            seat_present <= 1'b0;
        end else begin
            if (any_on) begin
                seat_present <= 1'b1;
            end else if (all_off) begin
                seat_present <= 1'b0;
            end
        end
    end

endmodule
