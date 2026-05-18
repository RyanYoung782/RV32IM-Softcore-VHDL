library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity program_counter is
	port(
		clk : in std_logic;
		reset : in std_logic;
		stall : in std_logic;
		jump_or_branch_condition : in std_logic;
		jump_or_branch_addr : in std_logic_vector(31 downto 0);
		pc_out : out std_logic_vector(31 downto 0);
		pc_plus4_out : out std_logic_vector(31 downto 0)
	);
end program_counter;
architecture rtl of program_counter is
	signal counter_register : std_logic_vector(31 downto 0) := (others => '0');
	signal counter_next : std_logic_vector(31 downto 0);
	signal counter_plus4 : std_logic_vector(31 downto 0);
	signal start: std_logic := '1';
begin
	--Combinational logic
	--Set counter + (size of word addr)
	counter_plus4 <= std_logic_vector(unsigned(counter_register) + 4);
	
	-- Combinational outputs — immediately reflect current register value
	pc_out <= counter_register;
	pc_plus4_out <= counter_plus4;
 
	--MUX the branch/jump with the (counter + 4). If branch condition high, next set to the branch/jump address, else, set to (counter + 4)
	branch: process(jump_or_branch_condition, jump_or_branch_addr, counter_plus4)
	begin
		if jump_or_branch_condition = '1' then
			counter_next <= jump_or_branch_addr;
		else
			counter_next <= counter_plus4;
		end if;
	end process;
	
	--Register update logic
	update_register: process(clk, reset)
	begin
		if reset = '1' then
			--reset counter
			counter_register <= (others => '0');
		elsif rising_edge(clk) then
			--Stall takes precedence :-)
			if start = '1' then
				start <= '0';
				counter_register <= counter_register;
			elsif stall = '1' then
				counter_register <= counter_register;
			else
				--updated counter
				counter_register <= counter_next;
			end if;
		end if;
	end process;
	
end rtl;