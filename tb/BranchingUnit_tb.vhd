library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity BranchingUnit_tb is
end entity;

architecture behavior of BranchingUnit_tb is

    -- DUT signals
    signal rs1_data : std_logic_vector(31 downto 0) := (others => '0');
    signal rs2_data : std_logic_vector(31 downto 0) := (others => '0');
    signal branch_op : std_logic_vector(2  downto 0) := (others => '0');
    signal branch : std_logic := '0';
    signal branch_taken : std_logic;

    component BranchingUnit is
        port(
            rs1_data : in  std_logic_vector(31 downto 0);
            rs2_data : in  std_logic_vector(31 downto 0);
            branch_op : in  std_logic_vector(2  downto 0);
            branch : in  std_logic;
            branch_taken : out std_logic
        );
    end component;

    -- Branch op funct3 constants
    constant BEQ : std_logic_vector(2 downto 0) := "000";
    constant BNE : std_logic_vector(2 downto 0) := "001";
    constant BLT : std_logic_vector(2 downto 0) := "100";
    constant BGE : std_logic_vector(2 downto 0) := "101";
    constant BLTU : std_logic_vector(2 downto 0) := "110";
    constant BGEU : std_logic_vector(2 downto 0) := "111";

    -- INT_MIN as SLV: avoids natural overflow for 0x80000000
    constant INT_MIN : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_signed(-2147483648, 32));

    function to_slv32(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(val, 32));
    end function;

    -- Procedure: apply inputs, wait for settle, compare, report
    procedure test_case (
        signal rs1 : out std_logic_vector(31 downto 0);
        signal rs2 : out std_logic_vector(31 downto 0);
        signal bop : out std_logic_vector(2  downto 0);
        signal br : out std_logic;
        signal bt : in  std_logic;
        variable t_run : inout integer;
        variable t_pass : inout integer;
        constant rs1_val : in  std_logic_vector(31 downto 0);
        constant rs2_val : in  std_logic_vector(31 downto 0);
        constant bop_val : in  std_logic_vector(2  downto 0);
        constant br_val : in  std_logic;
        constant expected : in  std_logic;
        constant test_label : in  string
    ) is
    begin
        rs1 <= rs1_val;
        rs2 <= rs2_val;
        bop <= bop_val;
        br  <= br_val;
        wait for 10 ns;

        t_run := t_run + 1;
        if bt = expected then
            t_pass := t_pass + 1;
            report "[PASS] " & test_label severity note;
        else
            report "[FAIL] " & test_label
                & "  expected=" & std_logic'image(expected)
                & "  got=" & std_logic'image(bt)
                severity error;
        end if;
    end procedure;

begin

    DUT: BranchingUnit
        port map(
            rs1_data => rs1_data,
            rs2_data => rs2_data,
            branch_op => branch_op,
            branch => branch,
            branch_taken => branch_taken
        );

    test_proc: process
        -- counters live inside the process as plain variables
        variable tests_run : integer := 0;
        variable tests_passed : integer := 0;
    begin

        -- ----------------------------------------------------------------
        -- branch=0 gate: suppress regardless of op/operands
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(5), to_slv32(5), BEQ, '0', '0',
            "branch=0, BEQ equal: NOT taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(1), to_slv32(2), BLT, '0', '0',
            "branch=0, BLT true cond: NOT taken");

        -- ----------------------------------------------------------------
        -- BEQ (000)
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(42), to_slv32(42), BEQ, '1', '1',
            "BEQ: equal positives -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(42), to_slv32(43), BEQ, '1', '0',
            "BEQ: unequal -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(0), BEQ, '1', '1',
            "BEQ: both zero -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(-1), to_slv32(-1), BEQ, '1', '1',
            "BEQ: both -1 (all ones) -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(-1), to_slv32(1), BEQ, '1', '0',
            "BEQ: -1 vs 1 -> not taken");

        -- ----------------------------------------------------------------
        -- BNE (001)
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(10), to_slv32(20), BNE, '1', '1',
            "BNE: unequal -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(10), to_slv32(10), BNE, '1', '0',
            "BNE: equal -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(0), BNE, '1', '0',
            "BNE: both zero -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(-1), to_slv32(0), BNE, '1', '1',
            "BNE: -1 vs 0 -> taken");

        -- ----------------------------------------------------------------
        -- BLT (100) – signed
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(-1), to_slv32(0), BLT, '1', '1',
            "BLT: -1 < 0 -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(-1), BLT, '1', '0',
            "BLT: 0 < -1 false -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(5), to_slv32(5), BLT, '1', '0',
            "BLT: equal -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(-100), to_slv32(1), BLT, '1', '1',
            "BLT: -100 < 1 -> taken");

        -- INT_MIN is negative signed but max-magnitude unsigned
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            INT_MIN, to_slv32(1), BLT, '1', '1',
            "BLT: INT_MIN < 1 (signed) -> taken");

        -- ----------------------------------------------------------------
        -- BGE (101) – signed
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(-1), BGE, '1', '1',
            "BGE: 0 >= -1 -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(5), to_slv32(5), BGE, '1', '1',
            "BGE: equal -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(-1), to_slv32(0), BGE, '1', '0',
            "BGE: -1 >= 0 false -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(1), INT_MIN, BGE, '1', '1',
            "BGE: 1 >= INT_MIN -> taken");

        -- ----------------------------------------------------------------
        -- BLTU (110) – unsigned
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(1), to_slv32(2), BLTU, '1', '1',
            "BLTU: 1 < 2 -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(2), to_slv32(1), BLTU, '1', '0',
            "BLTU: 2 < 1 false -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(0), BLTU, '1', '0',
            "BLTU: equal -> not taken");

        -- 0x80000000 is LARGE unsigned; opposite of BLT signed behavior
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(1), INT_MIN, BLTU, '1', '1',
            "BLTU: 1 < 0x80000000 (unsigned) -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            INT_MIN, to_slv32(1), BLTU, '1', '0',
            "BLTU: 0x80000000 < 1 (unsigned) false -> not taken");

        -- ----------------------------------------------------------------
        -- BGEU (111) – unsigned
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(2), to_slv32(1), BGEU, '1', '1',
            "BGEU: 2 >= 1 -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(5), to_slv32(5), BGEU, '1', '1',
            "BGEU: equal -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(1), BGEU, '1', '0',
            "BGEU: 0 >= 1 false -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            INT_MIN, to_slv32(1), BGEU, '1', '1',
            "BGEU: 0x80000000 >= 1 (unsigned) -> taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(1), INT_MIN, BGEU, '1', '0',
            "BGEU: 1 >= 0x80000000 (unsigned) false -> not taken");

        -- ----------------------------------------------------------------
        -- Invalid branch_op (others clause) with branch='1'
        -- ----------------------------------------------------------------
        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(0), "010", '1', '0',
            "Invalid op 010 -> not taken");

        test_case(rs1_data, rs2_data, branch_op, branch, branch_taken,
            tests_run, tests_passed,
            to_slv32(0), to_slv32(0), "011", '1', '0',
            "Invalid op 011 -> not taken");

        -- ----------------------------------------------------------------
        -- Summary
        -- ----------------------------------------------------------------
        report "Results: " & integer'image(tests_passed)
            & " / " & integer'image(tests_run) & " passed." severity note;
        if tests_passed = tests_run then
            report "ALL TESTS PASSED" severity note;
        else
            report integer'image(tests_run - tests_passed)
                & " TEST(S) FAILED" severity error;
        end if;

        wait;
    end process;

end architecture;