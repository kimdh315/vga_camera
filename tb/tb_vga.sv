`timescale 1ns / 1ps

module tb_vga ();

    logic       clk;
    logic       rst;
    logic [3:0] vgaRed;
    logic [3:0] vgaBlue;
    logic [3:0] vgaGreen;
    logic       Hsync;
    logic       Vsync;

    vga dut (
        .clk        (clk),
        .rst        (rst),
        .vgaRed     (vgaRed),
        .vgaBlue    (vgaBlue),
        .vgaGreen   (vgaGreen),
        .Hsync      (Hsync),
        .Vsync      (Vsync)
    );

    // CLK gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Task - See single frame RGB data
    task single_frame();
        wait (~Vsync);
        @(posedge clk);
        wait (Vsync);
        @(posedge clk);
    endtask

    // Main op
    initial begin
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        @(posedge clk);
        single_frame();
        single_frame();
        $stop();
    end

endmodule
