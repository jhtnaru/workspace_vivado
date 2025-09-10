transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xil_defaultlib

vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xil_defaultlib  -incr -v2k5 -l xil_defaultlib \
"../../../../basys3_exam.gen/sources_1/ip/xadc_joystick/xadc_joystick.v" \


vlog -work xil_defaultlib \
"glbl.v"

