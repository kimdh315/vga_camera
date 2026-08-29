`timescale 1ns / 1ps

module ov7670_setup_rom (
    input  [ 6:0] addr,
    output [15:0] data
);
    reg [15:0] rom[0:71];

    // Write setup sequence data to rom
    initial begin
        $readmemh("ov7670_setup.mem", rom);
    end

    assign data = rom[addr];
endmodule
