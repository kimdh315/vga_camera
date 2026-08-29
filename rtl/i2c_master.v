`timescale 1ns / 1ps

module i2c_master_top (
    input wire clk,
    input wire rst,
    // command port
    input wire cmd_start,
    input wire cmd_write,
    input wire cmd_read,
    input wire cmd_stop,
    // internal port
    input wire [7:0] tx_data,
    output wire [7:0] rx_data,
    input wire ack_in,  // read 시 master가 보낼 ACK(0)/NACK(1)
    output wire ack_out,  // write 시 slave로부터 받은 ACK(0)/NACK(1)
    output wire busy,
    output wire done,
    // external i2c port
    output wire scl,
    inout wire sda
);
    wire sda_o, sda_i;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    reg sdasync1, sdasync2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sdasync1 <= 0;
            sdasync2 <= 0;
        end else begin
            sdasync1 <= sda_i;
            sdasync2 <= sdasync1;
        end
    end

    I2C_Master u_i2c_master (
        .clk      (clk),
        .rst      (rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .ack_in   (ack_in),
        .ack_out  (ack_out),
        .busy     (busy),
        .done     (done),
        .scl      (scl),
        .sda_o    (sda_o),
        .sda_i    (sdasync2)
    );
endmodule

module I2C_Master (
    input wire clk,
    input wire rst,
    // command port
    input wire cmd_start,
    input wire cmd_write,
    input wire cmd_read,
    input wire cmd_stop,
    // internal port
    input wire [7:0] tx_data,
    output reg [7:0] rx_data,
    input wire ack_in,  // read 시 master가 보낼 ACK(0)/NACK(1)
    output reg ack_out,  // write 시 slave로부터 받은 ACK(0)/NACK(1)
    output wire busy,
    output reg done,
    // external i2c port
    output wire scl,
    output wire sda_o,
    input wire sda_i
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] START = 3'd1;
    localparam [2:0] WAIT_CMD = 3'd2;
    localparam [2:0] DATA = 3'd3;
    localparam [2:0] DATA_ACK = 3'd4;
    localparam [2:0] STOP = 3'd5;


    reg [2:0] state;

    reg [7:0] div_cnt;
    reg       qtr_tick;  // 1/4 SCL 주기마다 1clk 펄스
    reg       scl_r;
    reg       sda_r;
    reg [1:0] step;  // 상태 내 쿼터 진행 단계 (0~3)
    reg [7:0] tx_shift_reg;
    reg [7:0] rx_shift_reg;
    reg [2:0] bit_cnt;
    reg       is_read;
    reg       ack_in_r;

    assign scl   = scl_r;
    assign sda_o = sda_r;
    assign busy  = (state != IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt  <= 0;
            qtr_tick <= 1'b0;
        end else begin
            if (div_cnt == 250 - 1) begin
                div_cnt  <= 0;
                qtr_tick <= 1'b1;
            end else begin
                div_cnt  <= div_cnt + 1;
                qtr_tick <= 1'b0;
            end
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            scl_r        <= 1'b1;  // idle: SCL High
            sda_r        <= 1'b1;  // idle: SDA High (Hi-Z, pull-up high)
            step         <= 0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            rx_data      <= 0;
            is_read      <= 1'b0;
            bit_cnt      <= 0;
            ack_in_r     <= 1'b1;
            ack_out      <= 0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;
                    if (cmd_start) begin
                        state <= START;
                        step  <= 0;
                    end
                end
                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                WAIT_CMD: begin
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 0;
                        is_read      <= 1'b0;
                        state        <= DATA;
                    end else if (cmd_read) begin
                        rx_shift_reg <= 0;
                        bit_cnt      <= 0;
                        is_read      <= 1'b1;
                        ack_in_r     <= ack_in;
                        state        <= DATA;
                    end else if (cmd_stop) begin
                        state <= STOP;
                    end else if (cmd_start) begin
                        state <= START;
                    end
                end
                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                step  <= 2'd1;
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[7];
                            end
                            2'd1: begin
                                step  <= 2'd2;
                                scl_r <= 1'b1;
                            end
                            2'd2: begin
                                step  <= 2'd3;
                                scl_r <= 1'b1;
                                if (is_read) begin
                                    rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                                end
                            end
                            2'd3: begin
                                step  <= 2'd0;
                                scl_r <= 1'b0;
                                if (!is_read) begin
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                                if (bit_cnt == 7) begin
                                    state <= DATA_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt + 1;
                                end
                            end
                        endcase
                    end
                end
                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                step  <= 2'd1;
                                scl_r <= 1'b0;
                                if (is_read) begin
                                    sda_r <= ack_in_r;
                                end else begin
                                    sda_r <= 1'b1;
                                end
                            end
                            2'd1: begin
                                step  <= 2'd2;
                                scl_r <= 1'b1;
                            end
                            2'd2: begin
                                step  <= 2'd3;
                                scl_r <= 1'b1;
                                if (!is_read) begin
                                    ack_out <= sda_i;
                                end else begin
                                    rx_data <= rx_shift_reg;
                                end
                            end
                            2'd3: begin
                                step  <= 2'd0;
                                scl_r <= 1'b0;
                                done  <= 1'b1;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd0;
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
