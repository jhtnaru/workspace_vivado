vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xil_defaultlib

vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work xil_defaultlib -64 -incr -mfcu  \
"../../../../basys3_exam.gen/sources_1/ip/xadc_joystick/xadc_joystick.v" \


vlog -work xil_defaultlib \
"glbl.v"

