library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DataCache is
	generic(
		addressWidth := 10; --1024 storage locations
	);
	port(
		clk: in std_logic; --requires clock for synrchronous writes
		useEnabled: in std_logic;
		dataReadNotWrite: in std_logic;
		dataOperation : in data_access_size_t;
		dataAddress: in std_logic_vector(31 downto 0);
		writeData: in std_logic_vector(31 downto 0);
		readdata: out std_logic_vector(31 downto 0);
	);
end DataCache;

architecture rtl of DataCache is

	--Declare and instantiate the data memory. 1024*32 = 4KB
	type memory_t is array (0 to (2**addressWidth)-1) of std_logic_vector(31 downto 0);
	signal memory : memory_t := (others => (others => '0'));
	
	
begin		
	write_proc: process(clk)
		if rising_edge(clk) then
			

end architecture;
	
	