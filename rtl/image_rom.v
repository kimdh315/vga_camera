`timescale 1ns / 1ps

module image_rom (
    input             clk,
    input      [16:0] addr,
    output reg [15:0] data
);
    (* ram_style = "block" *)
    reg [15:0] mem[0:320*240-1];

    // Image Data Load
    initial begin
        $readmemh("Lenna_320x240.mem", mem);
    end

    always @(posedge clk) begin
        data <= mem[addr];
    end
endmodule
