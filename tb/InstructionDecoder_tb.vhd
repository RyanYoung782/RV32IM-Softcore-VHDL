library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_constants.all;

entity InstructionDecoder_tb is
end entity;

architecture behavior of InstructionDecoder_tb is

	component InstructionDecoder is 
		port(
			inputInstruction: in std_logic_vector(31 downto 0);
			
			--Register File Addresses (31 downto 0)
			registerAddress1: out std_logic_vector(4 downto 0);
			registerAddress2: out std_logic_vector(4 downto 0);
			destinationRegister: out std_logic_vector(4 downto 0);
			wbEnabled: out std_logic;
			
			--Immediate selection
			immVal : out std_logic_vector(31 downto 0);
			
			--EX Stage MUXes that help with operand selection and forwarding of values
			alu_op1_mux_select: out std_logic_vector(1 downto 0);
			alu_op2_mux_select: out std_logic_vector(1 downto 0);
			
			--Operation selection for the ALU and muldiv unit
			alu_op: out alu_op_t;
			muldiv_op: out muldiv_op_t;
			
			--Branching Signals
			branchOperation: out std_logic_vector(2 downto 0);
			branchEnabled: out std_logic;
			
			--Data Access Signals
			dataOperation: out std_logic_vector(2 downto 0);
			dataAccessEnabled: out std_logic;
			dataReadNotWrite: out std_logic;
			
			--WB stage signals
			wb_mux_select: out std_logic_vector(1 downto 0);	
			--For the HazardDetectionUnit to check which operation is firing
			--If muldivEnabled = '1', muldiv Operation, else alu Operation
			muldivEnabled : out std_logic
		);
	end component;
	
	--Internal Signals
	
	procedure test_case(
	
	) is
	begin
	
	
	end procedure;
begin
	DUT: InstructionDecoder
		port map(
		
		);
	test_proc: process
	
	begin
	
	end process;
end architecture;