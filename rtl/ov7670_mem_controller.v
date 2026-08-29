`timescale 1ns / 1ps

module ov7670_mem_controller #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter DW = 16,
    parameter AW = $clog2(IMG_W * IMG_H)
) (
    input           pclk,
    input           rst,
    input           href,
    input           vsync,
    input  [   7:0] pdata,
    output          we,
    output [AW-1:0] waddr,
    output [DW-1:0] wdata
);
    // Sequential Logic
    reg [AW-1:0] waddr_cnt, waddr_next;
    reg [DW-1:0] wdata_reg, wdata_next;
    reg we_reg, we_next;
    reg byte_flag, byte_flag_next;  // actually state

    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            waddr_cnt <= 0;
            byte_flag <= 0;
            wdata_reg <= 0;
            we_reg    <= 0;
        end else begin
            waddr_cnt <= waddr_next;
            byte_flag <= byte_flag_next;
            wdata_reg <= wdata_next;
            we_reg    <= we_next;
        end
    end

    // Combinational Logic
    always @(*) begin
        waddr_next     = waddr_cnt;
        wdata_next     = wdata_reg;
        we_next        = 1'b0;  // for 1 pulse
        byte_flag_next = byte_flag;

        if (we_reg) begin
            waddr_next = waddr_cnt + 1;
        end
        if (href) begin
            byte_flag_next = ~byte_flag;

            if (byte_flag) begin
                wdata_next[7:0] = pdata;
                we_next = 1'b1;
            end else begin
                wdata_next[15:8] = pdata;
            end
        end else if (vsync) begin
            byte_flag_next = 0;
            waddr_next    = 0;
        end
    end

    // Output Logic
    assign we = we_reg;
    assign waddr = waddr_cnt;
    assign wdata = wdata_reg;

endmodule
