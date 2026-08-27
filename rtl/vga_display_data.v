`timescale 1ns / 1ps

module vga_display_data #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input                       clk,
    input                       rst,
    input                       de,
    input                       mode,
    input  [$clog2(H_SIZE)-1:0] x_pixel,
    input  [$clog2(V_SIZE)-1:0] y_pixel,
    // input  [               3:0] input_red,
    // input  [               3:0] input_green,
    // input  [               3:0] input_blue,
    output [               3:0] vgaRed,
    output [               3:0] vgaGreen,
    output [               3:0] vgaBlue
);
    wire [11:0] vga_data;
    wire disparea;

    // ROM Reader
    wire [15:0] px_data;
    wire [16:0] vga_addr;

    vga_rom_reader U_VGA_ROM_READER (
        .mode    (mode),
        .x_pixel (x_pixel),
        .y_pixel (y_pixel),
        .px_data (px_data),
        .vga_addr(vga_addr),
        .vga_data(vga_data)
    );

    image_rom U_IMAGE_ROM (
        .clk (clk),
        .rst (rst),
        .addr(vga_addr),
        .data(px_data)
    );

    // Display Enable signal
    wire qvga_de;
    assign qvga_de = (x_pixel < 320) & (y_pixel < 240);
    assign disparea = mode ? de : qvga_de;

    // RGB output data
    assign vgaRed   = {4{disparea}} & vga_data[11:8];
    assign vgaGreen = {4{disparea}} & vga_data[7:4];
    assign vgaBlue  = {4{disparea}} & vga_data[3:0];
endmodule

module vga_rom_reader (
    input         mode,
    input  [ 9:0] x_pixel,
    input  [ 9:0] y_pixel,
    input  [15:0] px_data,
    output [16:0] vga_addr,
    output [11:0] vga_data
);
    wire [16:0] qvga_addr, upscale_addr;

    // QVGA Address
    assign qvga_addr = x_pixel + (y_pixel * 320);

    // VGA upscaler
    vga_upscaler U_VGA_UPSCALER (
        .x_pixel     (x_pixel),
        .y_pixel     (y_pixel),
        .upscale_addr(upscale_addr)
    );

    assign vga_addr = mode ? upscale_addr : qvga_addr;
    assign vga_data = {px_data[15:12], px_data[10:7], px_data[4:1]};
endmodule

module vga_upscaler (
    input  [ 9:0] x_pixel,
    input  [ 9:0] y_pixel,
    output [16:0] upscale_addr
);
    wire [9:0] x_pixel_valid, y_pixel_valid;

    assign x_pixel_valid = {1'b0, x_pixel[9:1]};
    assign y_pixel_valid = {1'b0, y_pixel[9:1]};
    assign upscale_addr  = x_pixel_valid + (y_pixel_valid * 320);
endmodule