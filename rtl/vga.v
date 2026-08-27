`timescale 1ns / 1ps

module vga #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input        clk,
    input        rst,
    input        mode,
    // input  [3:0] input_red,
    // input  [3:0] input_green,
    // input  [3:0] input_blue,
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
    wire [3:0] vgaRed_next, vgaGreen_next, vgaBlue_next;

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
        // .input_red  (input_red),
        // .input_green(input_green),
        // .input_blue (input_blue),
        .vgaRed  (vgaRed_next),
        .vgaBlue (vgaBlue_next),
        .vgaGreen(vgaGreen_next)
    );

    // Reg to match timing with BRAM
    reg Hsync_rt, Vsync_rt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Hsync_rt <= 1;
            Vsync_rt <= 1;
        end
        else begin
            Hsync_rt <= Hsync_next;
            Vsync_rt <= Vsync_next;
        end
    end


    // VGA output register - to avoid glitch
    vga_outreg U_VGA_OUTREG (
        .clk          (clk),
        .rst          (rst),
        .vgaRed_next  (vgaRed_next),
        .vgaGreen_next(vgaGreen_next),
        .vgaBlue_next (vgaBlue_next),
        .Hsync_next   (Hsync_rt),
        .Vsync_next   (Vsync_rt),
        .vgaRed       (vgaRed),
        .vgaGreen     (vgaGreen),
        .vgaBlue      (vgaBlue),
        .Hsync        (Hsync),
        .Vsync        (Vsync)
    );

endmodule

module vga_outreg (
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
