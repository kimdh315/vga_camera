`timescale 1ns / 1ps

module i2c_transaction (
    input             clk,
    input             rst,
    input             start,
    // AXI Slave Register
    input      [ 6:0] addr,
    input             is_read,    // i2c_addr register [7]
    input      [ 1:0] dataNum,
    input      [31:0] tdr,
    output reg [31:0] rdr,
    output reg        tr_done,
    output            tr_busy,
    // I2C Master IP
    output reg        cmd_start,
    output reg        cmd_stop,
    output reg        cmd_read,
    output reg        cmd_write,
    output reg        ack_in,
    input             ack_out,
    output reg [ 7:0] tx_data,
    input      [ 7:0] rx_data,
    input             done,
    input             busy
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CMD_START = 4'd1;
    localparam [3:0] WAIT_START = 4'd2;
    localparam [3:0] CMD_ADDR = 4'd3;
    localparam [3:0] WAIT_ADDR = 4'd4;
    localparam [3:0] CMD_WRITE = 4'd5;
    localparam [3:0] WAIT_WRITE = 4'd6;
    localparam [3:0] CMD_READ = 4'd7;
    localparam [3:0] WAIT_READ = 4'd8;
    localparam [3:0] CMD_STOP = 4'd9;
    localparam [3:0] WAIT_STOP = 4'd10;

    reg [3:0] state;

    reg [7:0] byte_cnt;  // to count number of data

    assign tr_busy = (state != IDLE);

    // Register for Latching
    reg [ 6:0] addr_r;
    reg        is_read_r;
    reg [ 1:0] dataNum_r;
    reg [31:0] tdr_r;

    // ---------------------------------
    // [1] Transaction Logic - FSM
    // ---------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;
            ack_in    <= 1'b0;
            tx_data   <= 8'd0;
            byte_cnt  <= 8'd0;
            rdr       <= 32'd0;
            tr_done   <= 1'b0;
            addr_r    <= 7'd0;
            is_read_r <= 1'b0;
            dataNum_r <= 2'd0;
            tdr_r     <= 32'd0;
        end else begin
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;
            tr_done   <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        // 입력값 캡처 (트랜잭션 중 변경 방지)
                        addr_r    <= addr;
                        is_read_r <= is_read;
                        dataNum_r <= dataNum;
                        tdr_r     <= tdr;
                        byte_cnt  <= 8'd0;
                        state     <= CMD_START;
                    end
                end

                CMD_START: begin
                    cmd_start <= 1'b1;  // 1-cycle 펄스
                    state     <= WAIT_START;
                end
                WAIT_START: begin
                    if (done) state <= CMD_ADDR;
                end

                CMD_ADDR: begin
                    cmd_write <= 1'b1;  // 1-cycle 펄스
                    tx_data   <= {addr_r, is_read_r};
                    state     <= WAIT_ADDR;
                end
                WAIT_ADDR: begin
                    if (done) begin
                        if (ack_out) begin  // NACK
                            state <= CMD_STOP;  // 즉시 STOP
                        end else if (is_read_r) begin
                            state <= CMD_READ;
                        end else begin
                            state <= CMD_WRITE;
                        end
                    end
                end

                CMD_WRITE: begin
                    cmd_write <= 1'b1;  // 1-cycle 펄스
                    tx_data   <= tdr_r[byte_cnt*8+:8];
                    state     <= WAIT_WRITE;
                end
                WAIT_WRITE: begin
                    if (done) begin
                        if (byte_cnt == dataNum_r) begin
                            state <= CMD_STOP;
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                            state    <= CMD_WRITE;
                        end
                    end
                end

                CMD_READ: begin
                    cmd_read <= 1'b1;  // 1-cycle 펄스
                    if (byte_cnt == dataNum_r)
                        ack_in <= 1'b1;  // NACK (마지막 바이트)
                    else ack_in <= 1'b0;  // ACK  (계속 읽기)
                    state <= WAIT_READ;
                end
                WAIT_READ: begin
                    if (done) begin
                        rdr[byte_cnt*8+:8] <= rx_data;
                        if (byte_cnt == dataNum_r) begin
                            state <= CMD_STOP;
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                            state    <= CMD_READ;
                        end
                    end
                end

                CMD_STOP: begin
                    cmd_stop <= 1'b1;  // 1-cycle 펄스
                    state    <= WAIT_STOP;
                end
                WAIT_STOP: begin
                    // I2C_Master STOP 완료 감지: busy=0 (done 미발생)
                    if (!busy) begin
                        tr_done <= 1'b1;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
