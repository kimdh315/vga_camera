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

module colorbar (
    input      [ 9:0] x_pixel,
    input      [ 9:0] y_pixel,
    input             de,
    output reg [11:0] vga_data
);

    // Color define
    localparam WHITE = 12'hfff;  // 12'b 1111 1111 1111 => 12'h RED GREEN BLUE
    localparam YELLOW = 12'hff0;
    localparam CYAN = 12'h0ff;
    localparam GREEN = 12'h0f0;
    localparam MAGENTA = 12'hf0f;
    localparam RED = 12'hf00;
    localparam BLUE = 12'h00f;
    localparam BLACK = 12'h000;
    localparam NAVY = 12'h258;
    localparam PURPLE = 12'h52a;
    localparam GRAY = 12'h777;
    localparam LGRAY = 12'haaa;
    localparam DGRAY = 12'h333;

    reg [1:0] row;
    reg [2:0] col7;
    reg [2:0] col_b;

    always @(*) begin
        if (y_pixel < 320) row = 2'd0;
        else if (y_pixel < 360) row = 2'd1;
        else row = 2'd2;
    end

    always @(*) begin
        if (x_pixel < 91) col7 = 3'd0;
        else if (x_pixel < 182) col7 = 3'd1;
        else if (x_pixel < 273) col7 = 3'd2;
        else if (x_pixel < 364) col7 = 3'd3;
        else if (x_pixel < 455) col7 = 3'd4;
        else if (x_pixel < 546) col7 = 3'd5;
        else col7 = 3'd6;
    end

    always @(*) begin
        if (x_pixel < 115) col_b = 3'd0;
        else if (x_pixel < 230) col_b = 3'd1;
        else if (x_pixel < 345) col_b = 3'd2;
        else if (x_pixel < 455) col_b = 3'd3;
        else if (x_pixel < 491) col_b = 3'd4;
        else if (x_pixel < 522) col_b = 3'd5;
        else if (x_pixel < 546) col_b = 3'd6;
        else col_b = 3'd7;
    end

    always @(*) begin
        vga_data = BLACK;
        if (de) begin
            case (row)
                2'd0:
                case (col7)
                    3'd0:    vga_data = WHITE;
                    3'd1:    vga_data = YELLOW;
                    3'd2:    vga_data = CYAN;
                    3'd3:    vga_data = GREEN;
                    3'd4:    vga_data = MAGENTA;
                    3'd5:    vga_data = RED;
                    default: vga_data = BLUE;
                endcase
                2'd1:
                case (col7)
                    3'd0:    vga_data = BLUE;
                    3'd1:    vga_data = BLACK;
                    3'd2:    vga_data = MAGENTA;
                    3'd3:    vga_data = BLACK;
                    3'd4:    vga_data = CYAN;
                    3'd5:    vga_data = BLACK;
                    default: vga_data = WHITE;
                endcase
                default:
                case (col_b)
                    3'd0:    vga_data = NAVY;
                    3'd1:    vga_data = WHITE;
                    3'd2:    vga_data = PURPLE;
                    3'd3:    vga_data = DGRAY;
                    3'd4:    vga_data = BLACK;
                    3'd5:    vga_data = DGRAY;
                    3'd6:    vga_data = LGRAY;
                    default: vga_data = DGRAY;
                endcase
            endcase
        end
    end

endmodule
