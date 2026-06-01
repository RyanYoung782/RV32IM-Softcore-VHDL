# RV32IM-Softcore-VHDL
Fully pipelined RV32IM softcore processor implemented and verified in VHDL, featuring a 5-stage pipeline, complete hazard detection and resolution, execution and memory stage forwarding, and branch resolution. Synthesizable RTL design for FPGA targets..

# Testing procedure:
1.) Each entity has a testbench file associated with it as a form of unit testing for each component

2.) The CPUDataPath_tb file acts as integration tests, where pipeline registers will be populated to see the effect of each pipeline stage running for dedicated amounts of clock cycles.

3.) Once the CPU is synthesized, End-to-End tests will be created by comparing the CPU output to an RV32IM emulator golden output. This will act as the final pillar of verification to ensure the ISA is satisfied and the chip works as intended.

# Key Design Decisions:
1.) Initial implementation: LUT-RAM I$ and D$. The initial design uses "perfect" LUT-RAM caches to ensure 1CC hit times for the instructions and data. This is expensive in terms of resources as there is dedicated LUTs going towards storing hard coded instruction memory. The data memory is dynamic in the sense that we can store different sized chunks of memory, but there is still a small, predefined amount of D$ storage. Future implementations will have split L1 caches and a unified L2 cache which will be backed by the FPGA BRAM. Cache policies will be decided based on what I have viewed as the most common cache setup in my Computer Architecture course: WB L1 cache and WT L2 with a data buffer. This will require a small bootloader to ensure the L1 I$ is fully populated with the first set of instructions.

2.) BRAM Memory mapping. This is a preemptive decision so I can have proper space for future processor expansions such as peripheral usage, UART or Ethernet connections, and interrupt handling. Instruction memory will start at 0x00000000 and end at __________. Data memory will start at __________ and end at __________. This is an important decision because it will allow me to restrict certain parts of memory as read only, or protected.

3.) MuldivUnit implementation: this is still a tentative plan, but to implement the M extension to this ISA, I will have a seperate unit which will execute over multiple cycles. There will be a MuldivEnabled signal to allow the unit to be used, and the pipeline will stall during the multicycle execution to ensure in order execution (for the time being). This being said, there will be a resultValid flag which tells the pipeline when the result is one cycle from being ready, and on the rising edge of the next clock cycle, the pipeline will contine with the multiplication/division result being available to be latched into the EXMEM pipeline register the rising edge of the next CC. The HazardDetectionUnit will handle stalling the pipeline for these results!

4.) Forwarding: All forwarding logic is contained within the HazardDetectionUnit. For EX/EX forwarding, the rd of the currently executing instruction will be compared to the rs1 and rs2 of the currently decoding instruction. If there is a dependency, a series of MUXes will funnel the forwarded value into the appropriate operand location for the next clock cycle. The possible forwarding values are ALUOutput, MuldivOutput, and PC+4. These MUX select signals are outputted in the HazardDetection Unit as registered values! They must be registered so that they execute in the proper clock cycle. For MEM/EX forwarding, very similar logic applies, but an additional MUX select value is needed: the data result.

5.) Future decisions to be made...
