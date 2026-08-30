`timescale 1ns / 1ps

module top (
    input        clk,
    input        rst,
    input        mode,
    input        sw_gray,
    input        sw_bin,
    input  [3:0] sw_bin_thr,
    // Camera
    output       xclk,
    input        pclk,
    input        cam_href,
    input        cam_vsync,
    input  [7:0] pdata,
    // VGA
    output       Hsync,
    output       Vsync,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    // I2C port
    output       scl,
    inout        sda
);
    pclk_gen U_CAM_CLK_GEN (
        .clk (clk),
        .rst (rst),
        .pclk(xclk)
    );

    // SCCB
    // ===============================
    sccb U_SCCB (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda(sda)
    );

    // OV7670 Memory Controller
    // ===============================
    wire [15:0] wdata;
    wire [16:0] waddr;
    wire we;
    ov7670_mem_controller U_OV7670_MEM_CONTROLLER (
        .pclk (pclk),
        .rst  (rst),
        .href (cam_href),
        .vsync(cam_vsync),
        .pdata(pdata),
        .we   (we),
        .waddr(waddr),
        .wdata(wdata)
    );

    // Frame Buffer
    // ===============================
    wire [15:0] rdata;
    wire [16:0] raddr;
    frame_buffer U_FRAME_BUFFER (
        .wclk (pclk),
        .we   (we),
        .waddr(waddr),
        .wdata(wdata),
        .rclk (clk),
        .raddr(raddr),
        .rdata(rdata)
    );

    // VGA Controller
    // ===============================
    wire [9:0] x_pixel, y_pixel;
    wire Hsync_next, Vsync_next;
    vga_controller U_VGA_CONTROLLER (
        .clk    (clk),
        .rst    (rst),
        .pclk   (xclk),
        .Hsync  (Hsync_next),
        .Vsync  (Vsync_next),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    // Frame Buffer
    // ===============================
    wire [3:0] vgaRed_raw, vgaGreen_raw, vgaBlue_raw;
    vga_display_data U_VGA_DISPLAY_DATA (
        .clk     (clk),
        .rst     (rst),
        .mode    (mode),
        .de      (de),
        .x_pixel (x_pixel),
        .y_pixel (y_pixel),
        .px_data (rdata),
        .vga_addr(raddr),
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

    // Synchronizer for Sync Signal
    // ===============================
    localparam LATENCY = 3;
    reg [LATENCY-1:0] Hsync_reg, Vsync_reg;
    wire Hsync_rt, Vsync_rt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Hsync_reg <= 0;
            Vsync_reg <= 0;
        end else begin
            Hsync_reg <= {Hsync_next, Hsync_reg[LATENCY-1:1]};
            Vsync_reg <= {Vsync_next, Vsync_reg[LATENCY-1:1]};
        end
    end

    assign Hsync_rt = Hsync_reg[0];
    assign Vsync_rt = Vsync_reg[0];

    // VGA Output register
    // ===============================
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
