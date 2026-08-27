`timescale 1ns / 1ps

module gray_filter (
    input            clk,
    input            rst,
    input            sw_gray,
    input      [3:0] input_red,
    input      [3:0] input_green,
    input      [3:0] input_blue,
    output reg [3:0] output_red,
    output reg [3:0] output_green,
    output reg [3:0] output_blue
);
    // Pipeline to avoid setup time violation
    wire [3:0] output_red_next, output_green_next, output_blue_next;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            output_red   <= 0;
            output_green <= 0;
            output_blue  <= 0;
        end else begin
            output_red   <= output_red_next;
            output_green <= output_green_next;
            output_blue  <= output_blue_next;
        end
    end

    // Combinational logic
    // Y calculation
    wire [11:0] y_prime;
    wire [11:0] red_valid, green_valid, blue_valid;
    assign red_valid   = 77 * input_red;
    assign green_valid = 150 * input_green;
    assign blue_valid  = 29 * input_blue;
    assign y_prime     = red_valid + green_valid + blue_valid;

    // Gray Filtered value
    wire [3:0] vgaRed_gray, vgaGreen_gray, vgaBlue_gray;
    assign vgaRed_gray       = y_prime[11:8];
    assign vgaGreen_gray     = y_prime[11:8];
    assign vgaBlue_gray      = y_prime[11:8];


    // Output selection mux
    assign output_red_next   = sw_gray ? vgaRed_gray : input_red;
    assign output_green_next = sw_gray ? vgaGreen_gray : input_green;
    assign output_blue_next  = sw_gray ? vgaBlue_gray : input_blue;
endmodule
