`timescale 1ns / 1ps

module frame_buffer #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter DW = 16,
    parameter AW = $clog2(IMG_W * IMG_H)
) (
    // write side (camera, pclk)
    input               wclk,
    input               we,
    input      [AW-1:0] waddr,
    input      [DW-1:0] wdata,
    // read side (VGA, clk)
    input               rclk,
    input      [AW-1:0] raddr,
    output reg [DW-1:0] rdata
);
    reg [DW-1:0] mem[0:IMG_H*IMG_W-1];

    // write
    always @(posedge wclk) begin
        if (we) begin
            mem[waddr] <= wdata;
        end
    end

    // read
    always @(posedge rclk) begin
        rdata <= mem[raddr];
    end
endmodule
