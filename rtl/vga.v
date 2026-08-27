`timescale 1ns / 1ps

module vga #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input        clk,
    input        rst,
    input        mode,
    input        sw_gray,
    input        sw_bin,
    input  [3:0] sw_bin_thr,
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
        .vgaRed  (vgaRed_raw),
        .vgaGreen(vgaGreen_raw),
        .vgaBlue (vgaBlue_raw)
    );

    // Gray filter
    wire [3:0] vgaRed_gstage, vgaGreen_gstage, vgaBlue_gstage;
    gray_filter U_GRAY_FILTER (
        .clk         (clk),
        .rst         (rst),
        .sw_gray     (sw_gray),
        .input_red   (vgaRed_raw),
        .input_green (vgaGreen_raw),
        .input_blue  (vgaBlue_raw),
        .output_red  (vgaRed_gstage),
        .output_green(vgaGreen_gstage),
        .output_blue (vgaBlue_gstage)
    );

    // Binary filter
    wire [3:0] vgaRed_binstage, vgaGreen_binstage, vgaBlue_binstage;
    binary_filter U_BIN_FILTER (
        .clk         (clk),
        .rst         (rst),
        .sw_bin      (sw_bin),
        .input_red   (vgaRed_gstage),
        .input_green (vgaGreen_gstage),
        .input_blue  (vgaBlue_gstage),
        .bin_thr     (sw_bin_thr),
        .output_red  (vgaRed_binstage),
        .output_green(vgaGreen_binstage),
        .output_blue (vgaBlue_binstage)
    );

    // Sync data timing matching
    localparam LATENCY = 2;
    reg [LATENCY-1:0] Hsync_reg, Vsync_reg;
    wire Hsync_rt, Vsync_rt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Hsync_reg <= 0;
            Vsync_reg <= 0;
        end else begin
            Hsync_reg <= {Hsync_reg[LATENCY-2:0], Hsync_next};
            Vsync_reg <= {Vsync_reg[LATENCY-2:0], Vsync_next};
        end
    end

    assign Hsync_rt = Hsync_reg[LATENCY-1];
    assign Vsync_rt = Vsync_reg[LATENCY-1];

    // VGA output register - to avoid glitch
    wire [3:0] vgaRed_next, vgaGreen_next, vgaBlue_next;
    assign vgaRed_next   = vgaRed_binstage;
    assign vgaGreen_next = vgaGreen_binstage;
    assign vgaBlue_next  = vgaBlue_binstage;
    vga_stagereg U_VGA_OUTREG (
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
