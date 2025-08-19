`timescale 1ns / 1ps

//
module tb_ultrasonic_cntr ();
    reg clk, reset_p;
    reg ultra_echo;
    wire ultra_trig;
    wire [11:0] distance;

    ultrasonic_cntr dut (clk, reset_p, ultra_echo, ultra_trig, distance);

    initial begin                               // Reset
        clk = 0;
        reset_p = 1;
        ultra_echo = 0;
    end

    always #5 clk = ~clk;                       // Create Clock, Low 5ns + High 5ns = 10ns

    initial begin
        #10;
        reset_p = 0; #10;
        wait(ultra_trig);
        wait(!ultra_trig);
        #10_000;
        ultra_echo = 1; #200_000;
        ultra_echo = 0; #100_000;
        $stop;
    end
endmodule
