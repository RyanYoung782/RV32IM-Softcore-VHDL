library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


 -- purpose:  evaluates branch conditions in the ex stage. compares
 --           the two source registers and asserts branch_taken based on branch_op.
 
--  internal logic:
--    purely combinatorial process(rs1_data, rs2_data, branch_op, branch)

--    if branch = '0': branch_taken <= '0'
--    else:
--      case branch_op is
--        "000" (beq):  branch_taken <= '1' when rs1_data = rs2_data
--        "001" (bne):  branch_taken <= '1' when rs1_data /= rs2_data
--        "100" (blt):  branch_taken <= '1' when signed(rs1_data) < signed(rs2_data)
--        "101" (bge):  branch_taken <= '1' when signed(rs1_data) >= signed(rs2_data)
--		  "110" (bltu): branch_taken <= '1' when unsigned(rs1_data) < unsigned(rs2_data)
--		  "111" (bgtu): branch_taken <= '1' when unsigned(rs1_data) >= unsigned(rs2_data)
--		  "010"  (JAL and JALR): branch_taken <= '1' (definite branch)
--        others:       branch_taken <= '0'


entity BranchingUnit is 
	port(
		rs1_data : in std_logic_vector(31 downto 0);  -- rs1 (from EX operand 1 MUX)
		rs2_data : in std_logic_vector(31 downto 0);  -- rs2 (from EX operand 2 MUX)
		branch_op : in std_logic_vector(2  downto 0);  -- branch type (from id/ex register)
		branch : in std_logic;  -- '1' = current instr is branch (branch_enable)
		branch_taken : out std_logic  -- '1' = condition met, take branch
	);
	
end	BranchingUnit;
	
architecture combo of BranchingUnit is
begin
	
	process (rs1_data, rs2_data, branch_op, branch)
	
	begin
		--Initial value to prevent false branching
		branch_taken <= '0';
		
		if branch = '1' then
			--Loop through all possible branching operations
			case branch_op is	
				when "000" => -- beq
					if (rs1_data = rs2_data) then 
						branch_taken <= '1';
					end if;
					
				when "001" => -- bne
					if (rs1_data /= rs2_data) then 
						branch_taken <= '1';
					end if;
					
				when "100" => -- blt
					if (signed(rs1_data) < signed(rs2_data)) then 
						branch_taken <= '1';
					end if;
					
				when "101" => -- bge
					if (signed(rs1_data) >= signed(rs2_data)) then 
						branch_taken <= '1';
					end if;
					
				when "110" => --bltu
					if (unsigned(rs1_data) < unsigned(rs2_data)) then	
						branch_taken <= '1';
					end if;
				
				when "111" => --bgeu
					if (unsigned(rs1_data) >= unsigned(rs2_data)) then
						branch_taken <= '1';
					end if;
				
				when "010" =>  --jal and jalr unconditional branching
					branch_taken <= '1';
						
				when others =>
					branch_taken <= '0';
					
			end case;
		end if;
	end process;
end combo;	
	
	
	
	
