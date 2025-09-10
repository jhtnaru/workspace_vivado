transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+xadc_joystick  -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.xadc_joystick xil_defaultlib.glbl

do {xadc_joystick.udo}

run 1000ns

endsim

quit -force
