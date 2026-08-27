`timescale 1ns / 1ps

module vga #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input        clk,
    input        rst,
    input        mode,
    input sw_gray,
    output [3:0] vgaRed,
    output [3:0] vgaBlue,
    output [3:0] vgaGreen,
    output       Hsync,
    output       Vsync
);
    // Wire
    wire [$clog2(H_SIZE)-1:0] x_pixel;
    wire [$clog2(V_SIZE)-1:0] y_pixel;
    wire de;

    // VGA controller
    wire Hsync_next, Vsync_next;

    vga_controller #(
        .H_SIZE(H_SIZE),
        .V_SIZE(V_SIZE)
    ) U_VGA_CONTROLLER (
        .clk    (clk),
        .rst    (rst),
        .Hsync  (Hsync_next),
        .Vsync  (Vsync_next),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    // VGA Display data
    wire [3:0] vgaRed_raw, vgaGreen_raw, vgaBlue_raw;
    wire [3:0] vgaRed_raw_next, vgaGreen_raw_next, vgaBlue_raw_next;

    vga_display_data #(
        .H_SIZE(H_SIZE),
        .V_SIZE(V_SIZE)
    ) U_VGA_DISPLAY_DATA (
        .clk     (clk),
        .rst     (rst),
        .de      (de),
        .x_pixel (x_pixel),
        .y_pixel (y_pixel),
        .mode    (mode),
        .vgaRed  (vgaRed_raw_next),
        .vgaGreen(vgaGreen_raw_next),
        .vgaBlue (vgaBlue_raw_next)
    );

    // Pipeline stage to avoid setup time violation
    wire Hsync_rt1, Vsync_rt1;
    vga_stagereg U_VGA_PIPELINE (
        .clk          (clk),
        .rst          (rst),
        .vgaRed_next  (vgaRed_raw_next),
        .vgaGreen_next(vgaGreen_raw_next),
        .vgaBlue_next (vgaBlue_raw_next),
        .Hsync_next   (Hsync_next),
        .Vsync_next   (Vsync_next),
        .vgaRed       (vgaRed_raw),
        .vgaGreen     (vgaGreen_raw),
        .vgaBlue      (vgaBlue_raw),
        .Hsync        (Hsync_rt1),
        .Vsync        (Vsync_rt1)
    );

    // Gray filter
    wire [3:0] vgaRed_gray, vgaGreen_gray, vgaBlue_gray;
    gray_filter U_GRAY_FILTER (
        .input_red   (vgaRed_raw),
        .input_green (vgaGreen_raw),
        .input_blue  (vgaBlue_raw),
        .output_red  (vgaRed_gray),
        .output_green(vgaGreen_gray),
        .output_blue (vgaBlue_gray)
    );

    // Mux to Select raw data or filtered data
    wire [3:0] vgaRed_next, vgaGreen_next, vgaBlue_next;
    assign vgaRed_next   = sw_gray ? vgaRed_gray : vgaRed_raw;
    assign vgaGreen_next = sw_gray ? vgaGreen_gray : vgaGreen_raw;
    assign vgaBlue_next  = sw_gray ? vgaBlue_gray : vgaBlue_raw;

    // Reg to match timing with BRAM
    reg Hsync_rt2, Vsync_rt2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Hsync_rt2 <= 1;
            Vsync_rt2 <= 1;
        end else begin
            Hsync_rt2 <= Hsync_rt1;
            Vsync_rt2 <= Vsync_rt1;
        end
    end


    // VGA output register - to avoid glitch
    vga_stagereg U_VGA_OUTREG (
        .clk          (clk),
        .rst          (rst),
        .vgaRed_next  (vgaRed_next),
        .vgaGreen_next(vgaGreen_next),
        .vgaBlue_next (vgaBlue_next),
        .Hsync_next   (Hsync_rt2),
        .Vsync_next   (Vsync_rt2),
        .vgaRed       (vgaRed),
        .vgaGreen     (vgaGreen),
        .vgaBlue      (vgaBlue),
        .Hsync        (Hsync),
        .Vsync        (Vsync)
    );

endmodule

module vga_stagereg (
    input            clk,
    input            rst,
    input      [3:0] vgaRed_next,
    input      [3:0] vgaGreen_next,
    input      [3:0] vgaBlue_next,
    input            Hsync_next,
    input            Vsync_next,
    output reg [3:0] vgaRed,
    output reg [3:0] vgaGreen,
    output reg [3:0] vgaBlue,
    output reg       Hsync,
    output reg       Vsync
);

    // Pipeline Register to avoid Glitch state output
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vgaRed   <= 0;
            vgaGreen <= 0;
            vgaBlue  <= 0;
            Hsync    <= 1;
            Vsync    <= 1;
        end else begin
            vgaRed   <= vgaRed_next;
            vgaGreen <= vgaGreen_next;
            vgaBlue  <= vgaBlue_next;
            Hsync    <= Hsync_next;
            Vsync    <= Vsync_next;
        end
    end

endmodule
