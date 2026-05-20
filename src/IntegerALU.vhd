library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IntegerALU is 
	port (
		alu_op : in std_logic_vector(9 downto 0);
		rs1 : in std_logic_vector(31 downto 0);
		rs2 : in std_logic_vector(31 downto 0);
		result : out std_logic_vector(31 downto 0)
	);
end IntegerALU;

architecture rtl of IntegerALU is

	--Internal Signals for signed and unsigned operands
	signal a_signed : signed(31 downto 0);
    signal b_signed : signed(31 downto 0);
    signal a_unsigned : unsigned(31 downto 0);
    signal b_unsigned : unsigned(31 downto 0);
	
	--Shift amount of shift operations
	signal shift_amount : integer range 0 to 31;
	
	--Operation output signals
	signal add_result : std_logic_vector(31 downto 0);
    signal sub_result : std_logic_vector(31 downto 0);
	signal and_result : std_logic_vector(31 downto 0);
    signal or_result : std_logic_vector(31 downto 0);
    signal xor_result : std_logic_vector(31 downto 0);
    signal sll_result : std_logic_vector(31 downto 0);
    signal srl_result : std_logic_vector(31 downto 0);
    signal sra_result : std_logic_vector(31 downto 0);
    signal slt_result : std_logic_vector(31 downto 0);
    signal sltu_result : std_logic_vector(31 downto 0);
	
	--ALU output temp signal
	signal alu_result  : std_logic_vector(31 downto 0);
	
begin
	--Assign unsigned, signed, and shift signals
	signal rs1_signed <= signed(rs1);
	signal rs2_signed <= signed(rs2);
	signal rs1_unsigned <= unsigned(rs1);
	signal rs2_unsigned <= unsigned(rs2);
	shift_amount <= to_integer(unsigned(rs2(4 downto 0)));
	
	--Assign all operations in parallel
	add_result <= std_logic_vector(a_signed + b_signed);
	sub_result <= std_logic_vector(a_signed - b_signed);
	xor_result <= rs1 xor rs2;
	or_result <= rs1 or rs2;
	and_result <= rs1 and rs2;
	sll_result <= std_logic_vector(shift_left(rs1_unsigned), shift_amount);
	srl_result <= std_logic_vector(shift_right(rs1_unsigned), shift_amount);
	sra_result <= std_logic_vector(shift_right(rs1_signed), shift_amount);
	slt_result <= x"00000001" when rs1_signed < rs2_signed else x"00000000";
	sltu_result <= x"00000001" when rs1_unsigned < rs2_unsigned else x"00000000";



    process(alu_op, add_result, sub_result, xor_result, or_result, and_result,
			sll_result, srl_result, sra_result, slt_result, sltu_result)
	begin
		case alu_op is
			when ALU_ADD => 
				alu_result <= add_result;
            when ALU_SUB => 
				alu_result <= sub_result;
            when ALU_AND => 
				alu_result <= and_result;
            when ALU_OR => 
				alu_result <= or_result;
            when ALU_XOR => 
				alu_result <= xor_result;
            when ALU_SLL => 
				alu_result <= sll_result;
            when ALU_SRL => 
				alu_result <= srl_result;
            when ALU_SRA => 
				alu_result <= sra_result;
            when ALU_SLT => 
				alu_result <= slt_result;
            when ALU_SLTU => 
				alu_result <= sltu_result;
			when ALU_LUI => 
				alu_result <= rs2;	--LUI result is same as just feeding immediate through. No computation necessary.
			when ALU_AUIPC => 
				alu_result <= add_result;  --AUIPC result the same as addition. No need to waste LUTs.
            when others => 
				alu_result <= (others => '0');
        end case;		
	end process;
	
	result <= alu_result;
end architecture;