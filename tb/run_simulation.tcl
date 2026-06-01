# run_simulation.tcl
# Usage: vsim -do run_simulation.tcl

# Compile all sources
vlib work
vmap work work
vcom -2008 src/riscv_constants.vhd
vcom -2008 src/InstructionCache.vhd
vcom -2008 src/DataCache.vhd
vcom -2008 src/RegisterFile.vhd
vcom -2008 src/ProgramCounter.vhd
vcom -2008 src/InstructionDecoder.vhd
vcom -2008 src/IntegerALU.vhd
vcom -2008 src/MuldivUnit.vhd
vcom -2008 src/BranchingUnit.vhd
vcom -2008 src/ForwardingUnit.vhd
vcom -2008 src/HazardDetectionUnit.vhd
vcom -2008 src/CPUDataPath.vhd
vcom -2008 src/TopLevelCPU.vhd

# Start simulation
vsim -t 1ns work.TopLevelCPU

# Load instruction memory from program.txt
# File should be one hex word per line, e.g. "00000013"
mem load -infile docs/program.txt -format binary \
    /TopLevelCPU/InstructionCacheInstance/memory

# Apply reset for 2 cycles
force -freeze /TopLevelCPU/clk 0 0, 1 5ns -repeat 10ns
force -freeze /TopLevelCPU/reset 1 0
run 20ns
force -freeze /TopLevelCPU/reset 0 0

# Run until the PC hits 0x00000000 again (program loops back to start)
# Or run for a fixed number of cycles — adjust as needed
run 5000ns

# Dump DataCache memory to memory.txt
set mem_file [open "docs/memory.txt" w]
set cache_depth 1024
for {set i 0} {$i < $cache_depth} {incr i} {
    set val [examine -hex \
        /TopLevelCPU/DataCacheInstance/memory($i)]
    puts $mem_file "$val"
}
close $mem_file

# Dump RegisterFile to register_file.txt
# Adjust the path to match your RegisterFile signal name
set reg_file [open "docs/register_file.txt" w]
set abi_names {
    zero ra sp gp tp t0 t1 t2
    s0   s1 a0 a1 a2 a3 a4 a5
    a6   a7 s2 s3 s4 s5 s6 s7
    s8   s9 s10 s11 t3 t4 t5 t6
}
for {set i 0} {$i < 32} {incr i} {
    set name [lindex $abi_names $i]
    set val [examine -hex \
        /TopLevelCPU/CPUDataPathInstance/RegisterFileInstance/all_regs($i)]
    puts $reg_file "x$i ($name): $val"
}
close $reg_file