library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity MuldivUnit is
	port(
		--Inputs
		clk: in std_logic;
		reset: in std_logic;
		
		operand1: in std_logic_vector(31 downto 0);
		operand2: in std_logic_vector(31 downto 0);
		muldiv_op: in muldiv_op_t;
		muldivEnabled: in std_logic;
		
		--Outputs
		muldivBusy: out std_logic;
		muldivResultValid: out std_logic;
		output: out std_logic_vector(31 downto 0)
	);
end MuldivUnit;

architecture rtl of MuldivUnit is

begin
	--No behavior for the time being!
	muldivBusy <= '0';
	muldivResultValid <= '0';
	output <= x"00000000";
end architecture;