library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FlipFlipSynchronizer is
	--Useful for dynamically choosing how many flip flops to use!
	--The more flip flops, the lower the *chance* of an error
	--There is no perfect solution to CDC, but this addresses the issue 
	--And makes it a game of chance that you can lower :D
	generic (
        STAGES : integer := 2;
		LATCHWIDTH : integer := 16  --Size of the FF registers
    );
    port (
        clk   : in  std_logic;
        async : in  std_logic_vector;
        sync  : out std_logic_vector
    );
end FlipFlopSynchronizer;

architecture arch of FlipFlipSynchronizer is
	
	type FFChain_t is array(0 to STAGES - 1) of std_logic_vector(LATCHWIDTH - 1 downto 0);
	signal chain : FFChain_t:= (others =>(others => '0'));
	
begin

	FFUpdate_proc : process(clk)
	begin
		if rising_edge(clk) then
			chain(0) <= async;
			for i in 1 to STAGES - 1 loop
				chain(i) <= chain(i - 1);
			end loop;
		end if;
	end process;
	
	sync <= chain(STAGES - 1);

end architecture;