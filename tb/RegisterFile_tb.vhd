library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity RegisterFile_tb is
end entity RegisterFile_tb;
 
architecture behavior of RegisterFile_tb is
 
	component RegisterFile is
		port(
			--clock and reset
			clk : in std_logic;
			reset : in std_logic;
			--write port
			reg_write : in std_logic;
			rd_addr : in std_logic_vector(4 downto 0);
			write_data : in std_logic_vector(31 downto 0);
			--read port 1
			rs1_addr : in std_logic_vector(4 downto 0);
			rs1_data : out std_logic_vector(31 downto 0);
			--read port 2
			rs2_addr : in std_logic_vector(4 downto 0);
			rs2_data : out std_logic_vector(31 downto 0)
		);
	end component RegisterFile;
 
	--Test signals
	signal clk : std_logic := '0';
	signal reset : std_logic := '0';
	signal reg_write : std_logic := '0';
	signal rd_addr : std_logic_vector(4 downto 0) := (others => '0');
	signal write_data : std_logic_vector(31 downto 0) := (others => '0');
	signal rs1_addr : std_logic_vector(4 downto 0) := (others => '0');
	signal rs1_data : std_logic_vector(31 downto 0);
	signal rs2_addr : std_logic_vector(4 downto 0) := (others => '0');
	signal rs2_data : std_logic_vector(31 downto 0);
 
	--Clock generation constant
	constant CLK_PERIOD : time := 1 ns;
 
	--Helper procedure to perform a write
	procedure write_register(
		signal clk_sig : in std_logic;
		signal reg_write_sig : out std_logic;
		signal rd_addr_sig : out std_logic_vector(4 downto 0);
		signal write_data_sig : out std_logic_vector(31 downto 0);
		addr : std_logic_vector(4 downto 0);
		data : std_logic_vector(31 downto 0)
	) is
	begin
		reg_write_sig <= '1';
		rd_addr_sig <= addr;
		write_data_sig <= data;
		wait until rising_edge(clk_sig);
		reg_write_sig <= '0';
		wait for 1 ns; --Allow propagation
	end procedure write_register;
 
	--Helper procedure to read and verify
	procedure verify_read(
		signal rs_addr : out std_logic_vector(4 downto 0);
		signal rs_data : in std_logic_vector(31 downto 0);
		addr : std_logic_vector(4 downto 0);
		expected : std_logic_vector(31 downto 0);
		test_name : string;
		variable error_count : inout integer
	) is
	begin
		rs_addr <= addr;
		wait for 2 ns; --Allow async read propagation
		if rs_data /= expected then
			report "FAIL: " & test_name
				severity error;
			error_count := error_count + 1;
		else
			report "PASS: " & test_name severity note;
		end if;
	end procedure verify_read;
 
begin
 
	DUT: RegisterFile
		port map(
			clk => clk,
			reset => reset,
			reg_write => reg_write,
			rd_addr => rd_addr,
			write_data => write_data,
			rs1_addr => rs1_addr,
			rs1_data => rs1_data,
			rs2_addr => rs2_addr,
			rs2_data => rs2_data
		);
 
	--Clock generation
	clk_gen : process
	begin
		clk <= '0';
		wait for CLK_PERIOD / 2;
		clk <= '1';
		wait for CLK_PERIOD / 2;
	end process clk_gen;
 
	test_proc : process
		variable error_count : integer := 0;
		variable total_tests : integer := 0;
	begin
 
		report " Register file test bench " severity note;
		report "Testing 32-register file with async reads and sync writes" severity note;
 
		--Reset Test 
		report "" severity note;
		report "--- Reset Verification ---" severity note;
 
		reset <= '1';
		wait for 3 * CLK_PERIOD;
		reset <= '0';
		wait for 1 ns;
 
		--Verify all registers are zero after reset
		for i in 0 to 31 loop
			verify_read(rs1_addr, rs1_data, 
				std_logic_vector(to_unsigned(i, 5)), 
				x"00000000",
				"RESET: Register " & integer'image(i) & " is zero",
				error_count);
			total_tests := total_tests + 1;
		end loop;
 
		--Zero Register Behavior 
		report "" severity note;
		report "--- Zero Register (R0) Tests ---" severity note;
 
		--Try to write to zero register
		report "Attempting to write 0x12345678 to R0" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "00000", x"12345678");
		
		--Verify R0 is still zero
		verify_read(rs1_addr, rs1_data, "00000", x"00000000",
			"ZERO REG: R0 remains zero after write attempt", error_count);
		total_tests := total_tests + 1;
 
		--Try to write a different value to R0
		report "Attempting to write 0xFFFFFFFF to R0" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "00000", x"FFFFFFFF");
		
		verify_read(rs1_addr, rs1_data, "00000", x"00000000",
			"ZERO REG: R0 remains zero after write of 0xFFFFFFFF", error_count);
		total_tests := total_tests + 1;
 
		--Basic Write and Read Tests 
		report "" severity note;
		report "--- Basic Write and Read Tests ---" severity note;
 
		--Write to R1
		report "Writing 0x12345678 to R1" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "00001", x"12345678");
		
		--Verify write by reading R1
		verify_read(rs1_addr, rs1_data, "00001", x"12345678",
			"BASIC: Read R1 after write", error_count);
		total_tests := total_tests + 1;
 
		--Write to R2
		report "Writing 0xABCDEF00 to R2" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "00010", x"ABCDEF00");
		
		--Verify write by reading R2
		verify_read(rs1_addr, rs1_data, "00010", x"ABCDEF00",
			"BASIC: Read R2 after write", error_count);
		total_tests := total_tests + 1;
 
		--Dual Port Async Read Tests 
		report "" severity note;
		report "--- Dual Port Async Read Tests ---" severity note;
 
		--Write test values to multiple registers
		report "Writing test values to registers 3-8" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "00011", x"11111111");
		write_register(clk, reg_write, rd_addr, write_data, "00100", x"22222222");
		write_register(clk, reg_write, rd_addr, write_data, "00101", x"33333333");
		write_register(clk, reg_write, rd_addr, write_data, "00110", x"44444444");
 
		wait for 2 ns;
 
		--Read simultaneously from both ports
		rs1_addr <= "00011";
		rs2_addr <= "00100";
		wait for 2 ns;
 
		if rs1_data /= x"11111111" or rs2_data /= x"22222222" then
			report "FAIL: DUAL READ: Simultaneous read from R3 and R4" severity error;
			error_count := error_count + 1;
		else
			report "PASS: DUAL READ: Simultaneous read from R3 and R4" severity note;
		end if;
		total_tests := total_tests + 1;
 
		--Read from different registers
		rs1_addr <= "00101";
		rs2_addr <= "00110";
		wait for 2 ns;
 
		if rs1_data /= x"33333333" or rs2_data /= x"44444444" then
			report "FAIL: DUAL READ: Simultaneous read from R5 and R6" severity error;
			error_count := error_count + 1;
		else
			report "PASS: DUAL READ: Simultaneous read from R5 and R6" severity note;
		end if;
		total_tests := total_tests + 1;
 
		--Internal Bypass Tests 
		report "" severity note;
		report "--- Internal Bypass (Forwarding) Tests ---" severity note;
 
		--Test bypass on rs1
		report "Testing bypass for rs1: writing 0xDEADBEEF to R10, reading from R10" severity note;
		reg_write <= '1';
		rd_addr <= "01010"; --R10
		write_data <= x"DEADBEEF";
		rs1_addr <= "01010"; --Read from R10
		wait for 2 ns; --Allow async bypass to work
 
		if rs1_data /= x"DEADBEEF" then
			report "FAIL: BYPASS RS1: Did not forward write value to rs1 during write" severity error;
			error_count := error_count + 1;
		else
			report "PASS: BYPASS RS1: Forwarded write value to rs1 during write" severity note;
		end if;
		total_tests := total_tests + 1;
 
		reg_write <= '0';
		wait for 1 ns;
 
		--Wait for clock edge to commit the write
		wait until rising_edge(clk);
		wait for 1 ns;
 
		--Verify the value was actually written
		verify_read(rs1_addr, rs1_data, "01010", x"DEADBEEF",
			"BYPASS: Verify R10 was written after bypass", error_count);
		total_tests := total_tests + 1;
 
		--Test bypass on rs2
		report "Testing bypass for rs2: writing 0xCAFEBABE to R15, reading from R15" severity note;
		reg_write <= '1';
		rd_addr <= "01111"; --R15
		write_data <= x"CAFEBABE";
		rs2_addr <= "01111"; --Read from R15
		wait for 2 ns; --Allow async bypass to work
 
		if rs2_data /= x"CAFEBABE" then
			report "FAIL: BYPASS RS2: Did not forward write value to rs2 during write" severity error;
			error_count := error_count + 1;
		else
			report "PASS: BYPASS RS2: Forwarded write value to rs2 during write" severity note;
		end if;
		total_tests := total_tests + 1;
 
		reg_write <= '0';
		wait for 1 ns;
 
		--Wait for clock edge
		wait until rising_edge(clk);
		wait for 1 ns;
 
		--Verify the write
		verify_read(rs2_addr, rs2_data, "01111", x"CAFEBABE",
			"BYPASS: Verify R15 was written after bypass", error_count);
		total_tests := total_tests + 1;
 
		--Test bypass on both ports simultaneously
		report "Testing bypass on both rs1 and rs2 simultaneously" severity note;
		reg_write <= '1';
		rd_addr <= "10000"; --R16
		write_data <= x"12345678";
		rs1_addr <= "10000"; --Read from R16 on rs1
		rs2_addr <= "10000"; --Read from R16 on rs2
		wait for 2 ns;
 
		if rs1_data /= x"12345678" or rs2_data /= x"12345678" then
			report "FAIL: BYPASS BOTH: Did not forward to both ports during write" severity error;
			error_count := error_count + 1;
		else
			report "PASS: BYPASS BOTH: Forwarded write value to both ports" severity note;
		end if;
		total_tests := total_tests + 1;
 
		reg_write <= '0';
		wait until rising_edge(clk);
		wait for 1 ns;
 
		--Bypass with Non-Matching Addresses 
		report "" severity note;
		report "--- Bypass Non-Match Tests (No Forwarding) ---" severity note;
 
		--Write to R17, read from R16 (should not bypass)
		report "Write to R17 while reading from R16 (no bypass expected)" severity note;
		
		--First, write a known value to R16
		write_register(clk, reg_write, rd_addr, write_data, "10000", x"AAAA0000");
		wait for 1 ns;
 
		--Now write to R17 while reading from R16
		reg_write <= '1';
		rd_addr <= "10001"; --Write to R17
		write_data <= x"BBBB0000";
		rs1_addr <= "10000"; --Read from R16
		wait for 2 ns;
 
		if rs1_data /= x"AAAA0000" then
			report "FAIL: NO BYPASS: rs1 changed when reading non-target register" severity error;
			error_count := error_count + 1;
		else
			report "PASS: NO BYPASS: rs1 correctly shows R16 (not R17 write data)" severity note;
		end if;
		total_tests := total_tests + 1;
 
		reg_write <= '0';
		wait until rising_edge(clk);
		wait for 1 ns;
 
		--Edge Cases 
		report "" severity note;
		report "--- Edge Case Tests ---" severity note;
 
		--Write all ones to all registers (except R0)
		report "Writing 0xFFFFFFFF to all registers except R0" severity note;
		for i in 1 to 31 loop
			write_register(clk, reg_write, rd_addr, write_data, 
				std_logic_vector(to_unsigned(i, 5)), x"FFFFFFFF");
		end loop;
 
		wait for 1 ns;
 
		--Verify all non-zero registers contain 0xFFFFFFFF
		for i in 1 to 31 loop
			verify_read(rs1_addr, rs1_data,
				std_logic_vector(to_unsigned(i, 5)), x"FFFFFFFF",
				"EDGE: Register " & integer'image(i) & " contains 0xFFFFFFFF",
				error_count);
			total_tests := total_tests + 1;
		end loop;
 
		--Write all zeros to all registers
		report "Writing 0x00000000 to all registers except R0" severity note;
		for i in 1 to 31 loop
			write_register(clk, reg_write, rd_addr, write_data,
				std_logic_vector(to_unsigned(i, 5)), x"00000000");
		end loop;
 
		wait for 1 ns;
 
		--Verify all non-zero registers contain 0x00000000
		for i in 1 to 31 loop
			verify_read(rs1_addr, rs1_data,
				std_logic_vector(to_unsigned(i, 5)), x"00000000",
				"EDGE: Register " & integer'image(i) & " contains 0x00000000",
				error_count);
			total_tests := total_tests + 1;
		end loop;
 
		--Boundary Register Tests 
		report "" severity note;
		report "--- Boundary Register Tests ---" severity note;
 
		--Test highest register address (R31)
		report "Testing highest register R31" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "11111", x"7FFFFFFF");
		verify_read(rs1_addr, rs1_data, "11111", x"7FFFFFFF",
			"BOUNDARY: R31 write and read", error_count);
		total_tests := total_tests + 1;
 
		--Test second register (R1) after other operations
		report "Testing R1 after extensive operations" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "00001", x"80000000");
		verify_read(rs1_addr, rs1_data, "00001", x"80000000",
			"BOUNDARY: R1 write and read", error_count);
		total_tests := total_tests + 1;
 
		--Consecutive Write Tests 
		report "" severity note;
		report "--- Consecutive Write Tests ---" severity note;
 
		--Write to R5, then immediately write to R6 (back-to-back)
		report "Consecutive writes to R5 then R6" severity note;
		reg_write <= '1';
		rd_addr <= "00101";
		write_data <= x"11111111";
		wait until rising_edge(clk);
 
		rd_addr <= "00110";
		write_data <= x"22222222";
		wait until rising_edge(clk);
 
		reg_write <= '0';
		wait for 1 ns;
 
		--Verify both writes succeeded
		verify_read(rs1_addr, rs1_data, "00101", x"11111111",
			"CONSEC: R5 consecutive write", error_count);
		total_tests := total_tests + 1;
 
		verify_read(rs1_addr, rs1_data, "00110", x"22222222",
			"CONSEC: R6 consecutive write", error_count);
		total_tests := total_tests + 1;
 
		--Write and Dual Read 
		report "" severity note;
		report "--- Write with Simultaneous Dual Read ---" severity note;
 
		--Write to R20 while reading from R19 and R20
		report "Writing 0x99999999 to R20 while reading R19 and R20" severity note;
		
		--First write to R19
		write_register(clk, reg_write, rd_addr, write_data, "10011", x"88888888");
		
		--Now write to R20 with bypass
		reg_write <= '1';
		rd_addr <= "10100"; --Write to R20
		write_data <= x"99999999";
		rs1_addr <= "10011"; --Read R19
		rs2_addr <= "10100"; --Read R20
		wait for 2 ns;
 
		if rs1_data /= x"88888888" then
			report "FAIL: WRITE+DUAL: rs1 incorrect (should be R19)" severity error;
			error_count := error_count + 1;
		elsif rs2_data /= x"99999999" then
			report "FAIL: WRITE+DUAL: rs2 did not forward from write" severity error;
			error_count := error_count + 1;
		else
			report "PASS: WRITE+DUAL: Both ports correct with bypass" severity note;
		end if;
		total_tests := total_tests + 1;
 
		reg_write <= '0';
		wait until rising_edge(clk);
		wait for 1 ns;
 
		--Multiple Writes and Reads to Same Register 
		report "" severity note;
		report "--- Multiple Writes to Same Register ---" severity note;
 
		--Write multiple values sequentially to R25
		report "Writing sequence of values to R25: 0x11111111 -> 0x22222222 -> 0x33333333" severity note;
		write_register(clk, reg_write, rd_addr, write_data, "11001", x"11111111");
		write_register(clk, reg_write, rd_addr, write_data, "11001", x"22222222");
		write_register(clk, reg_write, rd_addr, write_data, "11001", x"33333333");
		
		wait for 1 ns;
		
		verify_read(rs1_addr, rs1_data, "11001", x"33333333",
			"MULTI WRITE: R25 contains final write value", error_count);
		total_tests := total_tests + 1;
 
		--Test Summary 
		report "" severity note;
		report "Total tests executed: " & integer'image(total_tests) severity note;
		report "Errors found: " & integer'image(error_count) severity note;
 
		if error_count = 0 then
			report "ALL TESTS PASSED!" severity note;
		else
			report "SOME TESTS FAILED - Review errors above" severity error;
		end if;
		
		wait;
 
	end process test_proc;
 
end architecture;