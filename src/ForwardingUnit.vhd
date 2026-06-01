library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ForwardingUnit is
	port(
		--Inputs
		
		--IDEX Pipeline register input signals
		idex_rs1 : in std_logic_vector(4 downto 0);
		idex_op1MUXSelect : in std_logic;
		idex_rs2 : in std_logic_vector(4 downto 0);
		idex_op2MUXSelect : in std_logic;
		
		
		--EXMEM Pipeline register input signals
		exmem_rd : in std_logic_vector(4 downto 0);
		
		--MEMWB Pipeline register input signals
		memwb_rd : in std_logic_vector(4 downto 0);		
		
		--Outputs
		
		--RegFile vs EX-EX forwarding vs MEM-EX forwarding MUX select signals for operand 1 and 2
		rs1MUXSelect : out std_logic_vector(1 downto 0);
		rs2MUXSelect : out std_logic_vector(1 downto 0)	
	);
end ForwardingUnit;

architecture rtl of ForwardingUnit is 

begin
	generateMUXSelects_proc : process(idex_rs1, idex_op1MUXSelect, idex_rs2, idex_op2MUXSelect, exmem_rd, memwb_rd)
	
	begin
		--defaults
		rs1MUXSelect <= "00";
		rs2MUXSelect <= "00";
		
		--operand 1 MUXSelect Generation
		if idex_rs1 /= "00000" then --Zero Register Guard
			--EX-EX forwarding takes precedence
			if idex_rs1 = exmem_rd then
				rs1MUXSelect <= "10";
			--Check MEM-EX forwarding second
			elsif idex_rs1 = memwb_rd then
				rs1MUXSelect <= "11";
			end if;
		end if;
		
		--operand 2 MUXSelect Generation
		if idex_rs2 /= "00000" then --Zero Register Guard
			--EX-EX forwarding takes precedence
			if idex_rs2 = exmem_rd then
				rs2MUXSelect <= "10";
			--Check MEM-EX forwarding second
			elsif idex_rs2 = memwb_rd then
				rs2MUXSelect <= "11";
			end if;
		end if;
	end process;

end architecture;