library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity IntegerALU_tb is
end entity;
 
architecture behavior of IntegerALU_tb is
	
	--ALU operation type (in riscv_constants.vhd)
	type alu_op_t is (
		ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
		ALU_SLL, ALU_SRL, ALU_SRA, ALU_SLT, ALU_SLTU,
		ALU_LUI, ALU_AUIPC
	);
	
	component IntegerALU is
		port(
			alu_op : in alu_op_t;
			rs1 : in std_logic_vector(31 downto 0);
			rs2 : in std_logic_vector(31 downto 0);
			result : out std_logic_vector(31 downto 0)
		);
	end component;
	
	--Test signals
	signal alu_op : alu_op_t;
	signal rs1 : std_logic_vector(31 downto 0);
	signal rs2 : std_logic_vector(31 downto 0);
	signal result : std_logic_vector(31 downto 0);
	
	--Helper procedure to run a test case
	procedure test_case(
		signal alu_op_sig : out alu_op_t;
		signal rs1_sig : out std_logic_vector(31 downto 0);
		signal rs2_sig : out std_logic_vector(31 downto 0);
		signal result_sig : in std_logic_vector(31 downto 0);
		operation : alu_op_t;
		operand1 : std_logic_vector(31 downto 0);
		operand2 : std_logic_vector(31 downto 0);
		expected : std_logic_vector(31 downto 0);
		test_name : string;
		variable error_count : inout integer
	) is
	begin
		alu_op_sig <= operation;
		rs1_sig <= operand1;
		rs2_sig <= operand2;
		wait for 10 ns;
		
		if result_sig /= expected then
			report "FAIL: " & test_name & 
				" | Got: " & to_hstring(result_sig) & 
				" Expected: " & to_hstring(expected)
				severity error;
			error_count := error_count + 1;
		else
			report "PASS: " & test_name severity note;
		end if;
	end procedure;
	
begin
	
	DUT: IntegerALU
		port map(
			alu_op => alu_op,
			rs1 => rs1,
			rs2 => rs2,
			result => result
		);
	
	test_proc: process
		variable error_count : integer := 0;
		variable total_tests : integer := 0;
	begin
		
		report "Integer ALU tb" severity note;
		
		--ALU_ADD Tests 
		report "" severity note;
		report "--- Testing ALU_ADD (Addition) ---" severity note;
		
		--Basic addition
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"00000005", x"00000003", x"00000008", 
			"ADD: 5 + 3 = 8", error_count);
		total_tests := total_tests + 1;
		
		--Addition with zero
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"00000000", x"12345678", x"12345678",
			"ADD: 0 + 0x12345678 = 0x12345678", error_count);
		total_tests := total_tests + 1;
		
		--Addition resulting in zero
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"FFFFFFFF", x"00000001", x"00000000",
			"ADD: 0xFFFFFFFF + 1 = 0 (overflow)", error_count);
		total_tests := total_tests + 1;
		
		--Negative numbers (two's complement)
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"FFFFFFFE", x"FFFFFFFF", x"FFFFFFFD",
			"ADD: -2 + -1 = -3", error_count);
		total_tests := total_tests + 1;
		
		--Mixed signs
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"80000000", x"80000000", x"00000000",
			"ADD: -2147483648 + -2147483648 = 0 (overflow)", error_count);
		total_tests := total_tests + 1;
		
		--Maximum positive + maximum positive
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"7FFFFFFF", x"00000001", x"80000000",
			"ADD: 2147483647 + 1 = -2147483648 (overflow)", error_count);
		total_tests := total_tests + 1;
		
		--ALU_SUB Tests 
		report "" severity note;
		report "--- Testing ALU_SUB (Subtraction) ---" severity note;
		
		--Basic subtraction
		test_case(alu_op, rs1, rs2, result, ALU_SUB,
			x"0000000A", x"00000003", x"00000007",
			"SUB: 10 - 3 = 7", error_count);
		total_tests := total_tests + 1;
		
		--Subtraction resulting in zero
		test_case(alu_op, rs1, rs2, result, ALU_SUB,
			x"12345678", x"12345678", x"00000000",
			"SUB: 0x12345678 - 0x12345678 = 0", error_count);
		total_tests := total_tests + 1;
		
		--Negative result (underflow)
		test_case(alu_op, rs1, rs2, result, ALU_SUB,
			x"00000000", x"00000001", x"FFFFFFFF",
			"SUB: 0 - 1 = -1", error_count);
		total_tests := total_tests + 1;
		
		--Subtracting negative number
		test_case(alu_op, rs1, rs2, result, ALU_SUB,
			x"00000005", x"FFFFFFFE", x"00000007",
			"SUB: 5 - (-2) = 7", error_count);
		total_tests := total_tests + 1;
		
		--Maximum - minimum
		test_case(alu_op, rs1, rs2, result, ALU_SUB,
			x"7FFFFFFF", x"80000000", x"FFFFFFFF",
			"SUB: 2147483647 - (-2147483648) = -1 (overflow)", error_count);
		total_tests := total_tests + 1;
		
		--ALU_AND Tests 
		report "" severity note;
		report "--- Testing ALU_AND (Bitwise AND) ---" severity note;
		
		--Basic AND
		test_case(alu_op, rs1, rs2, result, ALU_AND,
			x"FFFFFFFF", x"0F0F0F0F", x"0F0F0F0F",
			"AND: 0xFFFFFFFF & 0x0F0F0F0F = 0x0F0F0F0F", error_count);
		total_tests := total_tests + 1;
		
		--AND with zero
		test_case(alu_op, rs1, rs2, result, ALU_AND,
			x"12345678", x"00000000", x"00000000",
			"AND: 0x12345678 & 0 = 0", error_count);
		total_tests := total_tests + 1;
		
		--AND with all ones
		test_case(alu_op, rs1, rs2, result, ALU_AND,
			x"ABCDEF00", x"FFFFFFFF", x"ABCDEF00",
			"AND: 0xABCDEF00 & 0xFFFFFFFF = 0xABCDEF00", error_count);
		total_tests := total_tests + 1;
		
		--Complementary patterns
		test_case(alu_op, rs1, rs2, result, ALU_AND,
			x"F0F0F0F0", x"0F0F0F0F", x"00000000",
			"AND: 0xF0F0F0F0 & 0x0F0F0F0F = 0", error_count);
		total_tests := total_tests + 1;
		
		--ALU_OR Tests 
		report "" severity note;
		report "--- Testing ALU_OR (Bitwise OR) ---" severity note;
		
		--Basic OR
		test_case(alu_op, rs1, rs2, result, ALU_OR,
			x"F0F0F0F0", x"0F0F0F0F", x"FFFFFFFF",
			"OR: 0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--OR with zero
		test_case(alu_op, rs1, rs2, result, ALU_OR,
			x"12345678", x"00000000", x"12345678",
			"OR: 0x12345678 | 0 = 0x12345678", error_count);
		total_tests := total_tests + 1;
		
		--OR with all ones
		test_case(alu_op, rs1, rs2, result, ALU_OR,
			x"ABCDEF00", x"FFFFFFFF", x"FFFFFFFF",
			"OR: 0xABCDEF00 | 0xFFFFFFFF = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--Identical operands
		test_case(alu_op, rs1, rs2, result, ALU_OR,
			x"55555555", x"55555555", x"55555555",
			"OR: 0x55555555 | 0x55555555 = 0x55555555", error_count);
		total_tests := total_tests + 1;
		
		--ALU_XOR Tests 
		report "" severity note;
		report "--- Testing ALU_XOR (Bitwise XOR) ---" severity note;
		
		--Basic XOR
		test_case(alu_op, rs1, rs2, result, ALU_XOR,
			x"FFFFFFFF", x"00000000", x"FFFFFFFF",
			"XOR: 0xFFFFFFFF ^ 0 = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--XOR with self (result should be 0)
		test_case(alu_op, rs1, rs2, result, ALU_XOR,
			x"12345678", x"12345678", x"00000000",
			"XOR: 0x12345678 ^ 0x12345678 = 0", error_count);
		total_tests := total_tests + 1;
		
		--XOR complementary patterns
		test_case(alu_op, rs1, rs2, result, ALU_XOR,
			x"F0F0F0F0", x"0F0F0F0F", x"FFFFFFFF",
			"XOR: 0xF0F0F0F0 ^ 0x0F0F0F0F = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--XOR toggle bits
		test_case(alu_op, rs1, rs2, result, ALU_XOR,
			x"AAAAAAAA", x"55555555", x"FFFFFFFF",
			"XOR: 0xAAAAAAAA ^ 0x55555555 = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--ALU_SLL Tests (Shift Left Logical) 
		report "" severity note;
		report "--- Testing ALU_SLL (Shift Left Logical) ---" severity note;
		
		--Basic left shift
		test_case(alu_op, rs1, rs2, result, ALU_SLL,
			x"00000001", x"00000001", x"00000002",
			"SLL: 1 << 1 = 2", error_count);
		total_tests := total_tests + 1;
		
		--Shift by 0 (no change)
		test_case(alu_op, rs1, rs2, result, ALU_SLL,
			x"12345678", x"00000000", x"12345678",
			"SLL: 0x12345678 << 0 = 0x12345678", error_count);
		total_tests := total_tests + 1;
		
		--Shift out of range
		test_case(alu_op, rs1, rs2, result, ALU_SLL,
			x"00000001", x"0000001F", x"80000000",
			"SLL: 1 << 31 = 0x80000000", error_count);
		total_tests := total_tests + 1;
		
		--Shift beyond 31 bits (shift amount = 32, implementation dependent)
		test_case(alu_op, rs1, rs2, result, ALU_SLL,
			x"00000001", x"00000020", x"00000000",
			"SLL: 1 << 32 = 0 (if 5-bit shift amount)", error_count);
		total_tests := total_tests + 1;
		
		--Shift with sign bit
		test_case(alu_op, rs1, rs2, result, ALU_SLL,
			x"80000000", x"00000001", x"00000000",
			"SLL: 0x80000000 << 1 = 0 (overflow)", error_count);
		total_tests := total_tests + 1;
		
		--ALU_SRL Tests (Shift Right Logical) 
		report "" severity note;
		report "--- Testing ALU_SRL (Shift Right Logical) ---" severity note;
		
		--Basic right shift
		test_case(alu_op, rs1, rs2, result, ALU_SRL,
			x"00000004", x"00000001", x"00000002",
			"SRL: 4 >> 1 = 2", error_count);
		total_tests := total_tests + 1;
		
		--Shift by 0 (no change)
		test_case(alu_op, rs1, rs2, result, ALU_SRL,
			x"ABCDEF12", x"00000000", x"ABCDEF12",
			"SRL: 0xABCDEF12 >> 0 = 0xABCDEF12", error_count);
		total_tests := total_tests + 1;
		
		--Logical right shift of negative number (fills with 0)
		test_case(alu_op, rs1, rs2, result, ALU_SRL,
			x"80000000", x"00000001", x"40000000",
			"SRL: 0x80000000 >> 1 = 0x40000000 (logical)", error_count);
		total_tests := total_tests + 1;
		
		--Shift all bits out
		test_case(alu_op, rs1, rs2, result, ALU_SRL,
			x"00000001", x"0000001F", x"00000000",
			"SRL: 1 >> 31 = 0", error_count);
		total_tests := total_tests + 1;
		
		--Shift beyond range
		test_case(alu_op, rs1, rs2, result, ALU_SRL,
			x"FFFFFFFF", x"00000020", x"00000000",
			"SRL: 0xFFFFFFFF >> 32 = 0", error_count);
		total_tests := total_tests + 1;
		
		--ALU_SRA Tests (Shift Right Arithmetic) 
		report "" severity note;
		report "--- Testing ALU_SRA (Shift Right Arithmetic) ---" severity note;
		
		--Arithmetic right shift of positive number
		test_case(alu_op, rs1, rs2, result, ALU_SRA,
			x"00000004", x"00000001", x"00000002",
			"SRA: 4 >> 1 = 2 (positive)", error_count);
		total_tests := total_tests + 1;
		
		--Arithmetic right shift of negative number (sign extends)
		test_case(alu_op, rs1, rs2, result, ALU_SRA,
			x"80000000", x"00000001", x"C0000000",
			"SRA: 0x80000000 >> 1 = 0xC0000000 (sign extend)", error_count);
		total_tests := total_tests + 1;
		
		--SRA by 0
		test_case(alu_op, rs1, rs2, result, ALU_SRA,
			x"FFFFFFFF", x"00000000", x"FFFFFFFF",
			"SRA: 0xFFFFFFFF >> 0 = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--Arithmetic right shift by 31 (preserves sign bit)
		test_case(alu_op, rs1, rs2, result, ALU_SRA,
			x"FFFFFFFF", x"0000001F", x"FFFFFFFF",
			"SRA: 0xFFFFFFFF >> 31 = 0xFFFFFFFF (all sign)", error_count);
		total_tests := total_tests + 1;
		
		--SRA of 0x7FFFFFFF >> 31 = 0
		test_case(alu_op, rs1, rs2, result, ALU_SRA,
			x"7FFFFFFF", x"0000001F", x"00000000",
			"SRA: 0x7FFFFFFF >> 31 = 0", error_count);
		total_tests := total_tests + 1;
		
		--ALU_SLT Tests (Set if Less Than, signed) 
		report "" severity note;
		report "--- Testing ALU_SLT (Set if Less Than - signed) ---" severity note;
		
		--rs1 < rs2 (true)
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"00000003", x"00000005", x"00000001",
			"SLT: 3 < 5 = 1 (true)", error_count);
		total_tests := total_tests + 1;
		
		--rs1 >= rs2 (false)
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"00000005", x"00000003", x"00000000",
			"SLT: 5 < 3 = 0 (false)", error_count);
		total_tests := total_tests + 1;
		
		--Equal values (false)
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"12345678", x"12345678", x"00000000",
			"SLT: 0x12345678 < 0x12345678 = 0", error_count);
		total_tests := total_tests + 1;
		
		--Negative < Positive
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"FFFFFFFF", x"00000000", x"00000001",
			"SLT: -1 < 0 = 1 (true)", error_count);
		total_tests := total_tests + 1;
		
		--Negative < Negative
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"FFFFFFFE", x"FFFFFFFF", x"00000001",
			"SLT: -2 < -1 = 1 (true)", error_count);
		total_tests := total_tests + 1;
		
		--Positive > Negative
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"00000000", x"FFFFFFFF", x"00000000",
			"SLT: 0 < -1 = 0 (false)", error_count);
		total_tests := total_tests + 1;
		
		--Boundary: max positive vs min negative
		test_case(alu_op, rs1, rs2, result, ALU_SLT,
			x"7FFFFFFF", x"80000000", x"00000000",
			"SLT: 2147483647 < -2147483648 = 0 (false)", error_count);
		total_tests := total_tests + 1;
		
		--ALU_SLTU Tests (Set if Less Than, unsigned) 
		report "" severity note;
		report "--- Testing ALU_SLTU (Set if Less Than - unsigned) ---" severity note;
		
		--rs1 < rs2 (unsigned, true)
		test_case(alu_op, rs1, rs2, result, ALU_SLTU,
			x"00000003", x"00000005", x"00000001",
			"SLTU: 3u < 5u = 1 (true)", error_count);
		total_tests := total_tests + 1;
		
		--rs1 >= rs2 (unsigned, false)
		test_case(alu_op, rs1, rs2, result, ALU_SLTU,
			x"00000005", x"00000003", x"00000000",
			"SLTU: 5u < 3u = 0 (false)", error_count);
		total_tests := total_tests + 1;
		
		--Large unsigned < small unsigned
		test_case(alu_op, rs1, rs2, result, ALU_SLTU,
			x"FFFFFFFF", x"00000000", x"00000000",
			"SLTU: 0xFFFFFFFFu < 0u = 0 (false)", error_count);
		total_tests := total_tests + 1;
		
		--Small unsigned < large unsigned
		test_case(alu_op, rs1, rs2, result, ALU_SLTU,
			x"00000000", x"FFFFFFFF", x"00000001",
			"SLTU: 0u < 0xFFFFFFFFu = 1 (true)", error_count);
		total_tests := total_tests + 1;
		
		--Equal unsigned values
		test_case(alu_op, rs1, rs2, result, ALU_SLTU,
			x"80000000", x"80000000", x"00000000",
			"SLTU: 0x80000000u < 0x80000000u = 0", error_count);
		total_tests := total_tests + 1;
		
		--ALU_LUI Tests (Load Upper Immediate) 
		report "" severity note;
		report "--- Testing ALU_LUI (Load Upper Immediate) ---" severity note;
		
		--Basic LUI (use rs2 for immediate, zero lower bits)
		test_case(alu_op, rs1, rs2, result, ALU_LUI,
			x"00000000", x"12345678", x"12345678",
			"LUI: Load 0x12345678 into upper bits", error_count);
		total_tests := total_tests + 1;
		
		--LUI with zero immediate
		test_case(alu_op, rs1, rs2, result, ALU_LUI,
			x"00000000", x"00000000", x"00000000",
			"LUI: Load 0 = 0", error_count);
		total_tests := total_tests + 1;
		
		--LUI with all ones
		test_case(alu_op, rs1, rs2, result, ALU_LUI,
			x"00000000", x"FFFFFFFF", x"FFFFFFFF",
			"LUI: Load 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--LUI with sign bit set
		test_case(alu_op, rs1, rs2, result, ALU_LUI,
			x"00000000", x"80000000", x"80000000",
			"LUI: Load 0x80000000 (negative)", error_count);
		total_tests := total_tests + 1;
		
		--ALU_AUIPC Tests (Add Upper Immediate to PC) 
		report "" severity note;
		report "--- Testing ALU_AUIPC (Add Upper Immediate to PC) ---" severity note;
		
		--AUIPC: result = pc + (rs2 << 12)
		--Assuming PC = 0 for simplicity in this test
		test_case(alu_op, rs1, rs2, result, ALU_AUIPC,
			x"00000000", x"00000001", x"00001000",
			"AUIPC: 0 + (1 << 12) = 0x1000", error_count);
		total_tests := total_tests + 1;
		
		--AUIPC with zero immediate
		test_case(alu_op, rs1, rs2, result, ALU_AUIPC,
			x"00000000", x"00000000", x"00000000",
			"AUIPC: 0 + 0 = 0", error_count);
		total_tests := total_tests + 1;
		
		--AUIPC with large immediate
		test_case(alu_op, rs1, rs2, result, ALU_AUIPC,
			x"00000000", x"FFFFFFFF", x"FFFFF000",
			"AUIPC: 0 + (0xFFFFFFFF << 12) = 0xFFFFF000", error_count);
		total_tests := total_tests + 1;
		
		--AUIPC with sign extended immediate
		test_case(alu_op, rs1, rs2, result, ALU_AUIPC,
			x"00000000", x"80000000", x"80000000",
			"AUIPC: 0 + (0x80000000) = 0x80000000", error_count);
		total_tests := total_tests + 1;
		
		--Additional Edge Cases 
		report "" severity note;
		report "--- Additional Edge Cases ---" severity note;
		
		--All zeros across operations
		test_case(alu_op, rs1, rs2, result, ALU_ADD,
			x"00000000", x"00000000", x"00000000",
			"ADD: 0 + 0 = 0", error_count);
		total_tests := total_tests + 1;
		
		--All ones across operations
		test_case(alu_op, rs1, rs2, result, ALU_AND,
			x"FFFFFFFF", x"FFFFFFFF", x"FFFFFFFF",
			"AND: 0xFF...FF & 0xFF...FF = 0xFF...FF", error_count);
		total_tests := total_tests + 1;
		
		--Alternating bit patterns
		test_case(alu_op, rs1, rs2, result, ALU_OR,
			x"AAAAAAAA", x"55555555", x"FFFFFFFF",
			"OR: 0xAAAAAAAA | 0x55555555 = 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
		
		--Test Summary 
		report "Total tests executed: " & integer'image(total_tests) severity note;
		report "Errors found: " & integer'image(error_count) severity note;
		
		if error_count = 0 then
			report "ALL TESTS PASSED!" severity note;
		else
			report "SOME TESTS FAILED - Review errors above" severity error;
		end if;
		
		
		wait;
		
	end process;
	
end architecture;