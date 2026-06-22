library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.instruction_memory.all;

entity InstructionCache is
	generic(
		addressWidth: integer := 9 --512 possible instructions can be stored
	);
	port(
		currAddress: in std_logic_vector(31 downto 0);
		currInstruction: out std_logic_vector(31 downto 0)
	);
end InstructionCache;

architecture rtl of InstructionCache is
	
	--Dynamic definition of total cache space
	constant TOT_SPACE : integer := 2**addressWidth;
	
	--512x32 = 16384 bits of instruction storage!
	--type mem_t is array(0 to TOT_SPACE - 1) of std_logic_vector(31 downto 0);
	
	--instantiating the memory object and indexing object
	--signal memory : mem_t := (others => x"00000000");
	signal memory : rom_t := PROGRAM;
	attribute rom_style : string;
	attribute rom_style of memory : signal is "distributed";
	signal index : integer range 0 to TOT_SPACE - 1;
begin
	--Obtain index, then return the memory there.
	--PC counts in increments of 4, so we disregard the bottom two bits of input addr.
	index <= to_integer(unsigned(currAddress(addressWidth + 1 downto 2)));
	currInstruction <= memory(index);
end architecture;