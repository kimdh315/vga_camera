`timescale 1ns / 1ps

module vga_controller #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input                         clk,
    input                         rst,
    output                        Hsync,
    output                        Vsync,
    output [$clog2(H_SIZE)-1 : 0] x_pixel,
    output [$clog2(V_SIZE)-1 : 0] y_pixel,
    output                        de
);
    // Wire
    wire pclk;

    wire [$clog2(H_SIZE)-1 : 0] h_count;
    wire [$clog2(V_SIZE)-1 : 0] v_count;

    // PCLK generator
    pclk_gen U_PCLK_GEN (
        .clk (clk),
        .rst (rst),
        .pclk(pclk)
    );

    // Pixel Counter
    pixel_counter #(
        .H_SIZE(H_SIZE),
        .V_SIZE(V_SIZE)
    ) U_PIXEL_COUNTER (
        .clk    (clk),
        .rst    (rst),
        .pclk   (pclk),
        .h_count(h_count),
        .v_count(v_count)
    );

    // VGA Decoder
    vga_decoder #(
        .H_SIZE(H_SIZE),
        .V_SIZE(V_SIZE)
    ) U_VGA_DECODER (
        .h_count(h_count),
        .v_count(v_count),
        .Hsync  (Hsync),
        .Vsync  (Vsync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

endmodule

module vga_decoder #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input  [$clog2(H_SIZE)-1 : 0] h_count,
    input  [$clog2(V_SIZE)-1 : 0] v_count,
    output                        Hsync,
    output                        Vsync,
    output [$clog2(H_SIZE)-1 : 0] x_pixel,
    output [$clog2(V_SIZE)-1 : 0] y_pixel,
    output                        de
);
    // Local parameter - 640 * 480 @ 60Hz Industry standard timing
    localparam H_VISIBLE_SIZE = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE = 96;
    localparam H_BACK_PORCH = 48;
    localparam H_WHOLE_LINE = 800;

    localparam V_VISIBLE_SIZE = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_PULSE = 2;
    localparam V_BACK_PORCH = 33;
    localparam V_WHOLE_FRAME = 525;

    // pixel value
    assign x_pixel = h_count;
    assign y_pixel = v_count;

    // Sync signal
    assign Hsync = ~((h_count >= H_VISIBLE_SIZE + H_FRONT_PORCH) & (h_count < H_WHOLE_LINE - H_BACK_PORCH));
    assign Vsync = ~((v_count >= V_VISIBLE_SIZE + V_FRONT_PORCH) & (v_count < V_WHOLE_FRAME - V_BACK_PORCH));

    // Display enable
    assign de = (h_count < H_VISIBLE_SIZE) & (v_count < V_VISIBLE_SIZE);
endmodule

module pixel_counter #(
    parameter H_SIZE = 800,
    parameter V_SIZE = 525
) (
    input                               clk,
    input                               rst,
    input                               pclk,
    output reg [$clog2(H_SIZE) - 1 : 0] h_count,
    output reg [$clog2(V_SIZE) - 1 : 0] v_count
);
    reg [$clog2(H_SIZE)-1 : 0] h_count_next;
    reg [$clog2(V_SIZE)-1 : 0] v_count_next;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (pclk) begin
                h_count <= h_count_next;
                v_count <= v_count_next;
            end
        end
    end

    // Next counter value
    always @(*) begin
        h_count_next = h_count + 1;
        v_count_next = v_count;
        if (h_count == H_SIZE - 1) begin
            h_count_next = 0;
            v_count_next = v_count + 1;
            if (v_count == V_SIZE - 1) begin
                v_count_next = 0;
            end
        end
    end

endmodule

module pclk_gen (
    input      clk,
    input      rst,
    output reg pclk
);
    // PCLK frequency = 25MHz
    reg pclk_next;
    reg [1:0] p_cnt, p_cnt_next;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            p_cnt <= 0;
            pclk  <= 0;
        end else begin
            p_cnt <= p_cnt_next;
            pclk  <= pclk_next;
        end
    end

    always @(*) begin
        pclk_next  = 0;
        p_cnt_next = p_cnt + 1;
        if (p_cnt == 2'd3) begin
            p_cnt_next = 0;
            pclk_next  = 1;
        end
    end
endmodule
