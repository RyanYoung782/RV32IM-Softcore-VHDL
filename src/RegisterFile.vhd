library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RegisterFile is
  port(
    -- clock and reset
    clk : in std_logic;  -- rising-edge system clock
    reset : in std_logic;  -- synchronous active-high reset

    -- write port
    reg_write : in std_logic;  -- write enable (active-high)
    rd_addr : in std_logic_vector(4 downto 0);  -- destination register address
    write_data : in std_logic_vector(31 downto 0);  -- data written when reg_write is high

    -- read port 1
    rs1_addr : in std_logic_vector(4 downto 0);  -- source register 1 address
    rs1_data : out std_logic_vector(31 downto 0); -- source register 1 data (combinational)

    -- read port 2
    rs2_addr : in std_logic_vector(4 downto 0);  -- source register 2 address
    rs2_data : out std_logic_vector(31 downto 0));  -- source register 2 data (combinational)

end entity RegisterFile;

architecture rtl of RegisterFile is

	--array of 32 32-bit registers, we will skip zero register, as it will always stay at 0.
	type reg_array is array(0 to 31) of std_logic_vector(31 downto 0);
	signal all_regs : reg_array := x"00000000";

	begin
	-- synchronous write
	write_proc : process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
			-- clear all 32 registers synchronously
				for i in 0 to 31 loop
					all_regs(i) <= (others => '0');
				end loop;
			elsif reg_write = '1' then
			-- write only when enabled and target is not the zero register
				if rd_addr /= "00000" then
					all_regs(to_integer(unsigned(rd_addr))) <= write_data;
				end if;
			end if;
		end if;
	end process write_proc;
	
	
	-- asynchronous reads
	-- address 0 always returns zero
	-- pretty straight forward, access the array index by converting the input std_logic into unsigned then integer, set the output to the value
	--Internal Forwarding Path for same cycle read before writes!
	--This will check if the reg_write is high (writeback at rising edge of next CC) and allow us to internally forward that result to a consuming register before it is written. Necessary for avoiding 
	read_proc: process(rs1_addr, rs2_addr, reg_write, rd_addr, write_data)
		if (reg_write = '1') then
			--rs1 check
			if rs1_addr = rd_addr then
				--internal forwarding
				rs1_data <= write_data;
			else 
				--else use register file saved value. Guard set for zero register
				rs1_data <= (others => '0') when rs1_addr = "00000" else all_regs(to_integer(unsigned(rs1_addr)));
			end if;
				
			--rs2 check
			if rs2_addr = rd_addr then
				--internal forwarding
				rs2_data <= write_data;
			else 
				--else use register file saved value. Guard set for zero register
				rs2_data <= (others => '0') when rs2_addr = "00000" else all_regs(to_integer(unsigned(rs2_addr)));
			end if;
		end if;
	end process;
end architecture;
