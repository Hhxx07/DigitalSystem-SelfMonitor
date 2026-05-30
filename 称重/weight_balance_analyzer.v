// 四角称重重心分布分析模块。
// 输入四角重量值（左前、左后、右前、右后），
// 输出前后/左右总和、差分以及平衡等级。
module weight_balance_analyzer (
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

    // 计算前后/左右总重量（扩展到 17 位防止溢出）。
    assign front_weight_sum = {1'b0, weight_left_front} + {1'b0, weight_right_front};
    assign rear_weight_sum  = {1'b0, weight_left_rear}  + {1'b0, weight_right_rear};
    assign left_weight_sum  = {1'b0, weight_left_front} + {1'b0, weight_left_rear};
    assign right_weight_sum = {1'b0, weight_right_front} + {1'b0, weight_right_rear};

    // 前后差分 = |前总 - 后总|，左右差分 = |左总 - 右总|。
    assign front_back_diff = (front_weight_sum >= rear_weight_sum) ?
                             (front_weight_sum - rear_weight_sum) :
                             (rear_weight_sum - front_weight_sum);
    assign left_right_diff = (left_weight_sum >= right_weight_sum) ?
                             (left_weight_sum - right_weight_sum) :
                             (right_weight_sum - left_weight_sum);

    // 平衡等级：0=居中，1=偏移，2=严重偏移。
    // 前后阈值：差 < 50 为居中，50..149 为偏移，>=150 为严重偏移。
    // 左右阈值：差 < 40 为居中，40..119 为偏移，>=120 为严重偏移。
    assign front_back_balance = (front_back_diff < 17'd50)  ? 2'd0 :
                                (front_back_diff < 17'd150) ? 2'd1 : 2'd2;
    assign left_right_balance = (left_right_diff < 17'd40)  ? 2'd0 :
                                (left_right_diff < 17'd120) ? 2'd1 : 2'd2;

endmodule
