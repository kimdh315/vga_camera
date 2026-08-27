`timescale 1ns / 1ps

module gray_filter (
    input  [3:0] input_red,
    input  [3:0] input_green,
    input  [3:0] input_blue,
    output [3:0] output_red,
    output [3:0] output_green,
    output [3:0] output_blue
);
    // Y calculation
    wire [11:0] y_prime;
    wire [11:0] red_valid, green_valid, blue_valid;
    assign red_valid   = 77 * input_red;
    assign green_valid = 150 * input_green;
    assign blue_valid  = 29 * input_blue;
    assign y_prime     = red_valid + green_valid + blue_valid;

    // Output
    assign output_red   = y_prime[11:8];
    assign output_green = y_prime[11:8];
    assign output_blue  = y_prime[11:8];
endmodule
