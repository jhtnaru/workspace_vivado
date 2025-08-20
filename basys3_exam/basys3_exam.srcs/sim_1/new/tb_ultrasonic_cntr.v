`timescale 1ns / 1ps

//
module tb_ultrasonic_cntr ();
    reg clk, reset_p;
    reg ultra_echo;
    wire ultra_trig;
    wire [11:0] distance;

    // Connect in Order
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
        wait(ultra_trig);                       // Trig Pin High Signal
        wait(!ultra_trig);                      // Trig Pin Low Signal
        #10_000;
        ultra_echo = 1; #1_000_000;             // Echo Pin High Signal, 1ms
        ultra_echo = 0; #100_000;               // Echo Pin Low Signal
        $stop;
    end
endmodule
