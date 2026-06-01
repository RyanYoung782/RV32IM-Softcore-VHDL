library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity ProgramCounter_tb is
end entity;

architecture behavior of ProgramCounter_tb is

    component ProgramCounter is
        port(
            clk : in  std_logic;
            reset : in  std_logic;
            stall : in  std_logic;
            branch_taken : in  std_logic;
            branch_addr: in  std_logic_vector(31 downto 0);
            pc : out std_logic_vector(31 downto 0);
            pc_plus_4 : out std_logic_vector(31 downto 0)
        );
    end component;

    -- DUT signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal stall : std_logic := '0';
    signal branch_taken : std_logic := '0';
    signal branch_addr: std_logic_vector(31 downto 0) := (others => '0');
    signal pc : std_logic_vector(31 downto 0);
    signal pc_plus_4 : std_logic_vector(31 downto 0);

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- Fail counter
    signal fail_count : integer := 0;

    -- Check procedure: samples outputs and compares against expected values
    procedure check(
        test_name : in string;
        exp_pc : in std_logic_vector(31 downto 0);
        exp_pc_plus4 : in std_logic_vector(31 downto 0);
        act_pc : in std_logic_vector(31 downto 0);
        act_pc_plus4 : in std_logic_vector(31 downto 0);
        signal fail_cnt : inout integer
    ) is
        variable failed : boolean := false;
    begin
        if act_pc /= exp_pc then
            report test_name & ": pc mismatch."
                severity error;
            failed := true;
        end if;
        if act_pc_plus4 /= exp_pc_plus4 then
            report test_name & ": pc_plus_4 mismatch."
                severity error;
            failed := true;
        end if;
        if not failed then
            report test_name & ": PASS" severity note;
        else
            fail_cnt <= fail_cnt + 1;
        end if;
    end procedure;

begin

    DUT: ProgramCounter
        port map(
            clk => clk,
            reset => reset,
            stall => stall,
            branch_taken => branch_taken,
            branch_addr => branch_addr,
            pc => pc,
            pc_plus_4 => pc_plus_4
        );

    --Clock generation
	clk_gen : process
	begin
		clk <= '0';
		wait for CLK_PERIOD / 2;
		clk <= '1';
		wait for CLK_PERIOD / 2;
	end process clk_gen;

    test_proc: process
    begin

        -- ===================================================================
        -- TEST 1: Reset behaviour
        -- Assert reset, hold for 2 cycles, check PC stays at 0x00000000
        -- ===================================================================
        reset <= '1';
        stall <= '0';
        branch_taken <= '0';
        branch_addr  <= (others => '0');

        wait until rising_edge(clk); wait for 1 ns;
        check("RESET cycle 1",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);

        wait until rising_edge(clk); wait for 1 ns;
        check("RESET cycle 2",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);

        -- ===================================================================
        -- TEST 2: Normal increment (reset released)
        -- PC should advance by 4 each cycle
        -- ===================================================================
        reset <= '0';

        wait until rising_edge(clk); wait for 1 ns;
        check("INCREMENT to 0x04",
              x"00000004", x"00000008",
              pc, pc_plus_4, fail_count);

        wait until rising_edge(clk); wait for 1 ns;
        check("INCREMENT to 0x08",
              x"00000008", x"0000000C",
              pc, pc_plus_4, fail_count);

        wait until rising_edge(clk); wait for 1 ns;
        check("INCREMENT to 0x0C",
              x"0000000C", x"00000010",
              pc, pc_plus_4, fail_count);

        -- ===================================================================
        -- TEST 3: Stall
        -- Assert stall for 3 cycles, PC must not change
        -- ===================================================================
        stall <= '1';

        wait until rising_edge(clk); wait for 1 ns;
        check("STALL cycle 1 (hold 0x0C)",
              x"0000000C", x"00000010",
              pc, pc_plus_4, fail_count);

        wait until rising_edge(clk); wait for 1 ns;
        check("STALL cycle 2 (hold 0x0C)",
              x"0000000C", x"00000010",
              pc, pc_plus_4, fail_count);

        wait until rising_edge(clk); wait for 1 ns;
        check("STALL cycle 3 (hold 0x0C)",
              x"0000000C", x"00000010",
              pc, pc_plus_4, fail_count);

        -- Release stall, PC should resume incrementing from 0x0C
        stall <= '0';

        wait until rising_edge(clk); wait for 1 ns;
        check("RESUME after stall to 0x10",
              x"00000010", x"00000014",
              pc, pc_plus_4, fail_count);

        -- ===================================================================
        -- TEST 4: Branch taken
        -- Branch to 0x00000100, next cycle PC should be 0x100
        -- ===================================================================
        branch_taken <= '1';
        branch_addr  <= x"00000100";

        wait until rising_edge(clk); wait for 1 ns;
        check("BRANCH TAKEN to 0x100",
              x"00000100", x"00000104",
              pc, pc_plus_4, fail_count);

        branch_taken <= '0';

        -- Verify normal increment continues from branch target
        wait until rising_edge(clk); wait for 1 ns;
        check("INCREMENT after branch to 0x104",
              x"00000104", x"00000108",
              pc, pc_plus_4, fail_count);

        -- ===================================================================
        -- TEST 5: Branch to address 0 (branch back to reset vector)
        -- ===================================================================
        branch_taken <= '1';
        branch_addr  <= x"00000000";

        wait until rising_edge(clk); wait for 1 ns;
        check("BRANCH to 0x00000000",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);

        branch_taken <= '0';

        -- ===================================================================
        -- TEST 6: Branch while stalled
        -- Stall takes priority over branch — PC must not update
        -- ===================================================================
        stall        <= '1';
        branch_taken <= '1';
        branch_addr <= x"000DEAD0";

        wait until rising_edge(clk); wait for 1 ns;
        check("STALL overrides BRANCH (hold 0x00)",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);

        stall        <= '0';
        branch_taken <= '0';

        -- ===================================================================
        -- TEST 7: Reset while running (mid-execution reset)
        -- ===================================================================
        -- Advance a few cycles first
        wait until rising_edge(clk); wait for 1 ns; -- pc = 0x04 (branch just fired before stall)
        wait until rising_edge(clk); wait for 1 ns; -- pc = 0x08

        reset <= '1';
        wait until rising_edge(clk); wait for 1 ns;
        check("MID-EXECUTION RESET",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);

        reset <= '0';

        -- ===================================================================
        -- TEST 8: Reset takes priority over branch
        -- ===================================================================
        branch_taken <= '1';
        branch_addr  <= x"FFFF0000";
        reset        <= '1';

        wait until rising_edge(clk); wait for 1 ns;
        check("RESET overrides BRANCH",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);

        reset        <= '0';
        branch_taken <= '0';

        -- ===================================================================
        -- TEST 9: Branch to maximum address (overflow boundary check)
        -- ===================================================================
        branch_taken <= '1';
        branch_addr <= x"FFFFFFFC";

        wait until rising_edge(clk); wait for 1 ns;
        check("BRANCH to 0xFFFFFFFC",
              x"FFFFFFFC", x"00000000",  -- pc+4 wraps to 0
              pc, pc_plus_4, fail_count);

        branch_taken <= '0';

        -- Increment from 0xFFFFFFFC should wrap pc_plus_4 to 0x00000000
        -- and the next cycle PC wraps to 0
        wait until rising_edge(clk); wait for 1 ns;
        check("INCREMENT wraps from 0xFFFFFFFC to 0x00000000",
              x"00000000", x"00000004",
              pc, pc_plus_4, fail_count);


        -- SUMMARY
        if fail_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "FAILURES: " & integer'image(fail_count) severity error;
        end if;

        wait;
    end process;

end architecture;