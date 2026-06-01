library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--High level structure of HazardDetectionUnit
--Inputs: Necessary Signals to detect branching, Load-Use Hazards, and Multi-cycle EX stalls.
--
--Because this CPU design does not support OoO Execution, we will not handle
--WAW or WAR hazards, as these would not occur.
--
--Logical Flow:
--1.) if branching, flush IFID, and IDEX registers. Resolution in the EX stage
--2.) elsif load-use hazard, stall PC and IFID pipeline registers. Insert a NOP bubble in the EX stage.
--3.) elsif muldiv busy, stall PC and IFID pipeline registers

entity HazardDetectionUnit is 
	port(
		--First register file consumer
		idRs1: in std_logic_vector(4 downto 0);
		
		--Second register file consumer
		idRs2: in std_logic_vector(4 downto 0);
		
		--BranchingUnit output
		branch_taken: in std_logic;
		
		--Load-Use Hazard Signals
		idex_dataEnabled : in std_logic;
		idex_dataReadNotWrite : in std_logic;
		idex_rd : in std_logic_vector(4 downto 0);
		
		--Multi-cycle EX stage
		muldivBusy: in std_logic;
		muldivResultValid: in std_logic;
		
		--Future expansions: imperfect data cache which requires stalling future instructions (IF, ID, EX stage stalls when cache updating)

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
	--Note that stalls and flushes take effect on the rising edge of the next CC.
	combo_proc: process(idRs1, idRs2, branch_taken, idex_dataEnabled, idex_dataReadNotWrite, idex_rd, muldivBusy, muldivResultValid)
	begin
		--Defaults
		ifid_flush <= '0';
		idex_flush <= '0';
		pc_stall <= '0';
		ifid_stall <= '0';
		idex_stall <= '0';
		
		--Check for Branch Instruction Firing in EX (could require flushes)
		if branch_taken = '1' then
			--Branch Resolution considerations
			ifid_flush <= '1'; 
			idex_flush <= '1';
			
		--Check for muldiv instruction firing
		elsif (muldivBusy = '1' and muldivResultValid = '0') then
			--Stall IF, ID, and EX until the muldiv is finished...
			pc_stall <= '1';
			ifid_stall <= '1';
			idex_stall <= '1';
		--Check for Load-Use Hazards
		elsif (idex_rd /= "00000" and idex_dataEnabled = '1' and idex_dataReadNotWrite = '1' and (idex_rd = idRs1 or idex_rd = idRs2)) then
			--Stall IF and ID and insert a NOP into the IDEX register
			pc_stall <= '1';
			ifid_stall <= '1';
			idex_flush <= '1';
		end if; 
	end process;

end architecture;