library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--High level structure of HazardDetectionUnit
--Inputs: Necessary Signals to detect branching, RAW hazards, and forwarding.
--
--Because this CPU design does not support OoO Execution, we will not handle
--WAW or WAR hazards, as these would not occur.
--
--Logical Flow:
--1.) Check for Branch firing. If so, flush necessary pipeline instructions 
--2.) If not Branching, check for idle muldiv unit. If so, proceed with forwarding considerations.
--3.) Else, muldiv firing, so stall the pipeline
--Outputs: pipeline stall, pipeline flush, and forwarding MUX select signals

entity HazardDetectionUnit is 
	port(
		--Forwarding Input Signals
		--ALU operand 1 signals
		idRs1: in std_logic_vector(4 downto 0);
		idMuxSelect1: in std_logic_vector(1 downto 0);
		
		--ALU operand 2 signals
		idRs2: in std_logic_vector(4 downto 0);
		idMuxSelect2: in std_logic_vector(1 downto 0);
		
		--EX stage forwarding signals
		exDestination: in std_logic_vector(4 downto 0);
		exWbEnabled: in std_logic;
		exWbMUXSelect: in std_logic_vector(1 downto 0); --Necessary to observe which MEM operation we can expect to be selected before it reaches WB
		
		--MEM stage forwarding Signals
		memDestination: in std_logic_vector(4 downto 0);
		memWbEnabled: in std_logic;
		memWbMUXSelect: in std_logic_vector(1 downto 0); --Necessary to observe which MEM operation we can expect to be selected before it reaches WB 
		
		--Stalling and Flushing Input Signals
		--Branching output (combinational portion, pre register latching at end of EX stage)
		branch_taken: in std_logic;
		
		--Multi-cycle EX stage
		muldivEnabled: in std_logic;
		muldivBusy: in std_logic;
		muldivResultValid: in std_logic;
		
		--Future expansions: imperfect data cache which requires stalling future instructions (IF, ID, EX stage stalls when cache updating)
	
		--Forwarding Output Signals
		--Operand 1 Signals
		--Select between what needs to be forwarded: EX alu, EX muldiv, EX PC+4, MEM alu, MEM muldiv, MEM PC+4, or MEM data (7-MUX!)
		operand1ForwardSelect: out std_logic_vector(2 downto 0);
		--Flag for if we want to forward the result
		operand1ForwardEnabled: out std_logic;
		
		--Operand 2 Signals
		operand2ForwardSelect: std_logic_vector(2 downto 0);
		operand2ForwardEnabled: out std_logic;
		
		--Flushing Output Signals
		ifid_flush: out std_logic;
		idex_flush: out std_logic;
		
		--Stalling Output Signals
		pc_stall: out std_logic;
		ifid_stall: out std_logic;
		idex_stall: out std_logic
	);
end HazardDetectionUnit;

architecture combo of HazardDetectionUnit is
	
begin
	combo_proc: process(all)
	begin
		--Defaults
		operand1ForwardSelect <= "000";
		operand1ForwardEnabled <= '0';
		operand2ForwardSelect <= "000";
		operand2ForwardEnabled <= '0';
		ifid_flush <= '0';
		idex_flush <= '0';
		pc_stall <= '0';
		ifid_stall <= '0';
		idex_stall <= '0';
		
		--Check for Branch Instruction Firing in EX (could require flushes)
		if branch_taken = '1' then
			--Branch Resolution considerations
			--Flush happens on rising edge of next CC
			ifid_flush <= '1'; 
			idex_flush <= '1';
			
		--Check for muldiv instruction idling (could proceed with forwarding)
		elsif (muldivBusy = '0' and muldivResultValid = '1') then
		
			--NOTE: Each operand MUST be considered independently
			
			--Operand 1 Forwarding considerations
			if (idRs1 /= "00000" ) then  --Guard against zero register forwarding...
				if (exDestination = idRs1 and exWbEnabled = '1')  then  --EX-EX considered first
					if exWbMUXSelect = "10" then --stall pipeline because data resolved in MEM stage
						pc_stall <= '1';
						ifid_stall <= '1';
						idex_flush <= '1'; --Insert NOP bubble :(
					else --Use wb MUX select signals to select correct forwarding value
						operand1ForwardEnabled <= '1';
						operand1ForwardSelect <= '0' & exWbMUXSelect;
					end if;
				
				elsif (memDestination = idRs1 and memWbEnabled = '1') then --Use an elsif for MEM-EX consideration because EX-EX takes precedence
					operand1ForwardEnabled <= '1';
					operand1ForwardSelect <= '1' & memWbMUXSelect;
				end if; 
			end if;
			
			--Operand 2 consideration
			if (idRs2 /= "00000" ) then  --Guard against zero register forwarding...
				if (exDestination = idRs2 and exWbEnabled = '1')  then  --EX-EX considered first
					if exWbMUXSelect = "10" then --stall pipeline because data resolved in MEM stage
						pc_stall <= '1';
						ifid_stall <= '1';
						idex_flush <= '1'; --Insert NOP bubble :(
					else --Use wb MUX select signals to select correct forwarding value
						operand2ForwardEnabled <= '1';
						operand2ForwardSelect <= '0' & exWbMUXSelect;
					end if;
				
				elsif (memDestination = idRs2 and memWbEnabled = '1') then --Use an elsif for MEM-EX consideration because EX-EX takes precedence
					operand2ForwardEnabled <= '1';
					operand2ForwardSelect <= '1' & memWbMUXSelect;
				end if; 
			end if;
		--Else, muldiv working! Stall the pipeline until finished
		else
			pc_stall <= '1';
			ifid_stall <= '1';
			idex_stall <= '1';
		end if; 
	end process;

end architecture;