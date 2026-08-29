`timescale 1ns / 1ps

module sccb (
    input  clk,
    input  rst,
    output scl,
    inout  sda
);
    // ov7670 Slave address
    parameter OV7670_ADDR = 7'h42;

    // State
    parameter [1:0] IDLE = 0;
    parameter [1:0] OPERATION = 1;
    parameter [1:0] WAIT = 2;
    parameter [1:0] DONE = 3;

    reg [1:0] c_state, n_state;

    // wire to connect FSM & Transaction module
    reg start_reg, start_next;
    reg [6:0] setup_addr, setup_addr_next;
    wire start;
    wire tr_done, tr_busy;
    wire [15:0] setup_data;

    assign start = start_reg;

    // Update Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state    <= IDLE;
            setup_addr <= 0;
            start_reg  <= 1'b0;
        end else begin
            c_state    <= n_state;
            setup_addr <= setup_addr_next;
            start_reg  <= start_next;
        end
    end

    // Next State Logic
    always @(*) begin
        n_state = c_state;
        setup_addr_next = setup_addr;
        start_next = 1'b0;  // for 1 pulse

        case (c_state)
            IDLE: begin
                n_state = OPERATION;
                start_next = 1'b1;
            end

            OPERATION: begin
                n_state = WAIT;
                setup_addr_next = setup_addr + 1;
            end

            WAIT: begin
                if (tr_done) begin
                    if (setup_addr == 71) begin
                        n_state = DONE;
                    end else begin
                        n_state = OPERATION;
                        start_next = 1'b1;
                    end
                end
            end

            DONE: begin
            end
        endcase
    end

    // OV7670 setup data memory
    // ===============================
    ov7670_setup_rom U_OV7670_SETUP_ROM (
        .addr(setup_addr),
        .data(setup_data)
    );

    // I2C Transaction unit to control I2C Sequence data
    // ===============================
    wire cmd_start, cmd_stop, cmd_read, cmd_write;
    wire ack_in, ack_out;
    wire [7:0] tx_data, rx_data;
    wire done, busy;
    i2c_transaction U_I2C_TRANSACTION (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .addr     (OV7670_ADDR),
        .is_read  (1'b0),                 // set to write only
        .dataNum  (2'b1),
        .tdr      ({16'b0, setup_data}),
        .rdr      (rdr),
        .tr_done  (tr_done),
        .tr_busy  (tr_busy),
        .cmd_start(cmd_start),
        .cmd_stop (cmd_stop),
        .cmd_read (cmd_read),
        .cmd_write(cmd_write),
        .ack_in   (ack_in),
        .ack_out  (ack_out),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .done     (done),
        .busy     (busy)
    );

    // I2C Master Module
    // ===============================
    i2c_master_top U_I2C_MASTER (
        .clk(clk),
        .rst(rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .cmd_stop(cmd_stop),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .ack_in(ack_in),  // read 시 master가 보낼 ACK(0)/NACK(1)
        .ack_out(ack_out),  // write 시 slave로부터 받은 ACK(0)/NACK(1)
        .busy(busy),
        .done(done),
        .scl(scl),
        .sda(sda)
    );


endmodule
