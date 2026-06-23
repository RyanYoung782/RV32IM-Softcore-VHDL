# How to run: 
# source ./tb/simulate_cpu.tcl

set clock_period 1ns
set num_cycles 500
set ram_size 1024
set num_registers 32

set program_file "docs/program.txt"
set memory_out_file "docs/memory.txt"
set register_out_file "docs/register_file.txt"


# Compile all sources
vlib work
vmap work work

vcom -2008 ./src/instruction_memory.vhd
vcom -2008 ./src/*

# Start simulation
vsim -t 1ps ./work.TopLevelCPU

view wave
add wave -r /TopLevelCPU/CPUDataPathInstance/HazardDetectionUnitInstance/ifid_flush
add wave -r /TopLevelCPU/CPUDataPathInstance/HazardDetectionUnitInstance/idex_flush
add wave -r /TopLevelCPU/CPUDataPathInstance/HazardDetectionUnitInstance/pc_stall
add wave -r /TopLevelCPU/CPUDataPathInstance/HazardDetectionUnitInstance/ifid_stall
add wave -r /TopLevelCPU/CPUDataPathInstance/HazardDetectionUnitInstance/idex_stall
add wave -r /TopLevelCPU/CPUDataPathInstance/InstructionDecoderInstance/inputInstruction
add wave -r /TopLevelCPU/CPUDataPathInstance/InstructionDecoderInstance/alu_op
add wave -r /TopLevelCPU/CPUDataPathInstance/InstructionDecoderInstance/dataOperation
add wave -r /TopLevelCPU/CPUDataPathInstance/ifid_currAddress
add wave -r /TopLevelCPU/async_switch_inputs
add wave -r /TopLevelCPU/led_output



# Load Program into InstructionCacheInstance memory  
# ModelSim memory loader porting program.txt line by line into InstructionCacheInstance memory array
# Here, each line of program.txt is a line of machine code as a 32bit binary number
# If instead we wanted to load HEX files in , just change to "-format hex"
# mem load -infile $program_file -format binary /TopLevelCPU/InstructionCacheInstance/memory
 
# Clokc + Reset generation
# Drive clock on the DUT port
force -freeze /TopLevelCPU/clk  0 0ns, 1 0.5ns -repeat 1ns
 
# Assert active low reset for 3 cycles, then deassert
force -freeze /TopLevelCPU/reset 0 0ns
run 3ns
force -freeze /TopLevelCPU/reset 1 0ns
run 5ns
force -freeze /TopLevelCPU/async_switch_inputs "1111111111111111" 0ns
 
# Run simulation for desired number of CCs
run [expr {$num_cycles * 1}]ns
 
# dumping DataCacheInstance memory array into a file (memory.txt)
# Runs line by line to take each 32-bit unsigned binary words from the cache and places into the file
set mem_fd [open $memory_out_file w]
for {set i 0} {$i < $ram_size} {incr i} {
    # Read 32-bit word from data memory array
    set val [examine -radix unsigned /TopLevelCPU/DataCacheInstance/memory($i)]
    # Format as 32-bit binary string
    set bin ""
    for {set b 31} {$b >= 0} {incr b -1} {
        set bin "$bin[expr {($val >> $b) & 1}]"
    }
    puts $mem_fd $bin
}
close $mem_fd
 
# dumping register file
# 32 registers each dumped as unsigned 32-bit binary values
set reg_fd [open $register_out_file w]
for {set i 0} {$i < $num_registers} {incr i} {
    set val [examine -radix unsigned /TopLevelCPU/CPUDataPathInstance/RegisterFileInstance/all_regs($i)]
    set bin ""
    for {set b 31} {$b >= 0} {incr b -1} {
        set bin "$bin[expr {($val >> $b) & 1}]"
    }
    puts $reg_fd $bin
}
close $reg_fd
 
puts "Simulation complete."
puts "  Data memory  -> $memory_out_file  ($ram_size lines)"
puts "  Register file -> $register_out_file ($num_registers lines)"
 
# Can either quit or view the waveform of the simulation!
#quit -sim
wave zoom full