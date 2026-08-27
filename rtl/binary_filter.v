`timescale 1ns / 1ps

module binary_filter (
    input            clk,
    input            rst,
    input            sw_bin,
    input      [3:0] input_red,
    input      [3:0] input_green,
    input      [3:0] input_blue,
    input      [3:0] bin_thr,
    // input            invert,
    output reg [3:0] output_red,
    output reg [3:0] output_green,
    output reg [3:0] output_blue
);
    // Stage Register to avoid setup time violation
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

    // Combinational Logic
    // Binary Filter
    wire [3:0] vgaRed_bin, vgaGreen_bin, vgaBlue_bin;
    assign vgaRed_bin        = (input_red > bin_thr) ? 4'hf : 4'h0;
    assign vgaGreen_bin      = (input_green > bin_thr) ? 4'hf : 4'h0;
    assign vgaBlue_bin       = (input_blue > bin_thr) ? 4'hf : 4'h0;

    // output logic
    assign output_red_next   = sw_bin ? vgaRed_bin : input_red;
    assign output_green_next = sw_bin ? vgaGreen_bin : input_green;
    assign output_blue_next  = sw_bin ? vgaBlue_bin : input_blue;
endmodule
