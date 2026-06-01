library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity InstructionDecoder_tb is
end entity;

architecture behavior of InstructionDecoder_tb is

    component InstructionDecoder is
        port(
            inputInstruction : in std_logic_vector(31 downto 0);
            registerAddress1 : out std_logic_vector(4 downto 0);
            registerAddress2 : out std_logic_vector(4 downto 0);
            destinationRegister : out std_logic_vector(4 downto 0);
            wbEnabled : out std_logic;
            immVal : out std_logic_vector(31 downto 0);
            alu_op1_mux_select : out std_logic_vector(1 downto 0);
            alu_op2_mux_select : out std_logic_vector(1 downto 0);
            alu_op : out alu_op_t;
            muldiv_op : out muldiv_op_t;
            branchOperation : out std_logic_vector(2 downto 0);
            branchEnabled : out std_logic;
            dataOperation : out data_access_size_t;
            dataAccessEnabled : out std_logic;
            dataReadNotWrite : out std_logic;
            wb_mux_select : out std_logic_vector(1 downto 0);
            muldivEnabled : out std_logic
        );
    end component;

    -- DUT signals
    signal inputInstruction : std_logic_vector(31 downto 0) := (others => '0');
    signal registerAddress1 : std_logic_vector(4 downto 0);
    signal registerAddress2 : std_logic_vector(4 downto 0);
    signal destinationRegister : std_logic_vector(4 downto 0);
    signal wbEnabled : std_logic;
    signal immVal : std_logic_vector(31 downto 0);
    signal alu_op1_mux_select : std_logic_vector(1 downto 0);
    signal alu_op2_mux_select : std_logic_vector(1 downto 0);
    signal alu_op : alu_op_t;
    signal muldiv_op : muldiv_op_t;
    signal branchOperation : std_logic_vector(2 downto 0);
    signal branchEnabled : std_logic;
    signal dataOperation : data_access_size_t;
    signal dataAccessEnabled : std_logic;
    signal dataReadNotWrite : std_logic;
    signal wb_mux_select : std_logic_vector(1 downto 0);
    signal muldivEnabled : std_logic;

    -- Test tracking
    signal test_num : integer := 0;
    signal fail_count : integer := 0;

    -- Instruction encoding helpers

    -- R-type:  funct7 | rs2 | rs1 | funct3 | rd | opcode
    function encode_r(funct7 : std_logic_vector(6 downto 0);
                      rs2 : std_logic_vector(4 downto 0);
                      rs1 : std_logic_vector(4 downto 0);
                      funct3 : std_logic_vector(2 downto 0);
                      rd : std_logic_vector(4 downto 0);
                      opcode : std_logic_vector(6 downto 0))
        return std_logic_vector is
    begin
        return funct7 & rs2 & rs1 & funct3 & rd & opcode;
    end function;

    -- I-type:  imm[11:0] | rs1 | funct3 | rd | opcode
    function encode_i(imm12 : std_logic_vector(11 downto 0);
                      rs1 : std_logic_vector(4 downto 0);
                      funct3 : std_logic_vector(2 downto 0);
                      rd : std_logic_vector(4 downto 0);
                      opcode : std_logic_vector(6 downto 0))
        return std_logic_vector is
    begin
        return imm12 & rs1 & funct3 & rd & opcode;
    end function;

    -- S-type:  imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
    function encode_s(imm12 : std_logic_vector(11 downto 0);
                      rs2 : std_logic_vector(4 downto 0);
                      rs1 : std_logic_vector(4 downto 0);
                      funct3 : std_logic_vector(2 downto 0);
                      opcode : std_logic_vector(6 downto 0))
        return std_logic_vector is
    begin
        return imm12(11 downto 5) & rs2 & rs1 & funct3 & imm12(4 downto 0) & opcode;
    end function;

    -- B-type:  imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
    function encode_b(imm13 : std_logic_vector(12 downto 0);  -- bit 0 ignored (always 0)
                      rs2 : std_logic_vector(4 downto 0);
                      rs1 : std_logic_vector(4 downto 0);
                      funct3 : std_logic_vector(2 downto 0);
                      opcode : std_logic_vector(6 downto 0))
        return std_logic_vector is
    begin
        -- imm13: [12][11][10:5][4:1][0(ignored)]
        return imm13(12) & imm13(10 downto 5) & rs2 & rs1 & funct3
             & imm13(4 downto 1) & imm13(11) & opcode;
    end function;

    -- U-type:  imm[31:12] | rd | opcode
    function encode_u(imm20 : std_logic_vector(19 downto 0);
                      rd : std_logic_vector(4 downto 0);
                      opcode : std_logic_vector(6 downto 0))
        return std_logic_vector is
    begin
        return imm20 & rd & opcode;
    end function;

    -- J-type:  imm[20|10:1|11|19:12] | rd | opcode
    function encode_j(imm21 : std_logic_vector(20 downto 0);  -- bit 0 ignored
                      rd : std_logic_vector(4 downto 0);
                      opcode : std_logic_vector(6 downto 0))
        return std_logic_vector is
    begin
        return imm21(20) & imm21(10 downto 1) & imm21(11) & imm21(19 downto 12) & rd & opcode;
    end function;


    -- Expected-immediate helpers (mirror decoder logic)

    function imm_i(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return (31 downto 12 => instr(31)) & instr(31 downto 20);
    end function;

    function imm_s(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return (31 downto 12 => instr(31)) & instr(31 downto 25) & instr(11 downto 7);
    end function;

    function imm_b(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return (31 downto 13 => instr(31)) & instr(31) & instr(7)
             & instr(30 downto 25) & instr(11 downto 8) & '0';
    end function;

    function imm_u(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(31 downto 12) & (11 downto 0 => '0');
    end function;

    function imm_j(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return (31 downto 21 => instr(31)) & instr(31) & instr(19 downto 12)
             & instr(20) & instr(30 downto 21) & '0';
    end function;

    procedure check(
        test_name : in string;
        instr : in std_logic_vector(31 downto 0);
        -- register ports
        exp_ra1 : in std_logic_vector(4 downto 0);
        exp_ra2 : in std_logic_vector(4 downto 0);
        exp_rd : in std_logic_vector(4 downto 0);
        exp_wb : in std_logic;
        -- immediate
        exp_imm : in std_logic_vector(31 downto 0);
        -- mux selects
        exp_op1_mux : in std_logic_vector(1 downto 0);
        exp_op2_mux : in std_logic_vector(1 downto 0);
        -- alu / muldiv
        exp_alu_op : in alu_op_t;
        exp_muldiv_op : in muldiv_op_t;
        exp_muldiv_en : in std_logic;
        -- branch
        exp_branch_op : in std_logic_vector(2 downto 0);
        exp_branch_en : in std_logic;
        -- data
        exp_data_op : in data_access_size_t;
        exp_data_en : in std_logic;
        exp_data_rnw : in std_logic;
        -- wb mux
        exp_wb_mux : in std_logic_vector(1 downto 0);
        -- DUT outputs (passed in as signals converted to values)
        act_ra1 : in std_logic_vector(4 downto 0);
        act_ra2 : in std_logic_vector(4 downto 0);
        act_rd : in std_logic_vector(4 downto 0);
        act_wb : in std_logic;
        act_imm : in std_logic_vector(31 downto 0);
        act_op1_mux : in std_logic_vector(1 downto 0);
        act_op2_mux : in std_logic_vector(1 downto 0);
        act_alu_op : in alu_op_t;
        act_muldiv_op : in muldiv_op_t;
        act_muldiv_en : in std_logic;
        act_branch_op : in std_logic_vector(2 downto 0);
        act_branch_en : in std_logic;
        act_data_op : in data_access_size_t;
        act_data_en : in std_logic;
        act_data_rnw : in std_logic;
        act_wb_mux : in std_logic_vector(1 downto 0);
        -- mutable fail counter
        signal fail_cnt : inout integer
    ) is
        variable failed : boolean := false;
    begin
        if act_ra1       /= exp_ra1       then report test_name & ": ra1 mismatch"       severity error; failed := true; end if;
        if act_ra2       /= exp_ra2       then report test_name & ": ra2 mismatch"       severity error; failed := true; end if;
        if act_rd        /= exp_rd        then report test_name & ": rd mismatch"        severity error; failed := true; end if;
        if act_wb        /= exp_wb        then report test_name & ": wbEnabled mismatch" severity error; failed := true; end if;
        if act_imm       /= exp_imm       then report test_name & ": immVal mismatch"    severity error; failed := true; end if;
        if act_op1_mux   /= exp_op1_mux   then report test_name & ": op1_mux mismatch"  severity error; failed := true; end if;
        if act_op2_mux   /= exp_op2_mux   then report test_name & ": op2_mux mismatch"  severity error; failed := true; end if;
        if act_alu_op    /= exp_alu_op    then report test_name & ": alu_op mismatch"    severity error; failed := true; end if;
        if act_muldiv_op /= exp_muldiv_op then report test_name & ": muldiv_op mismatch" severity error; failed := true; end if;
        if act_muldiv_en /= exp_muldiv_en then report test_name & ": muldivEnabled mismatch" severity error; failed := true; end if;
        if act_branch_op /= exp_branch_op then report test_name & ": branch_op mismatch" severity error; failed := true; end if;
        if act_branch_en /= exp_branch_en then report test_name & ": branch_en mismatch" severity error; failed := true; end if;
        if act_data_op   /= exp_data_op   then report test_name & ": data_op mismatch"  severity error; failed := true; end if;
        if act_data_en   /= exp_data_en   then report test_name & ": dataAccessEnabled mismatch" severity error; failed := true; end if;
        if act_data_rnw  /= exp_data_rnw  then report test_name & ": dataReadNotWrite mismatch"  severity error; failed := true; end if;
        if act_wb_mux    /= exp_wb_mux    then report test_name & ": wb_mux mismatch"   severity error; failed := true; end if;

        if not failed then
            report test_name & ": PASS" severity note;
        else
            fail_cnt <= fail_cnt + 1;
        end if;
    end procedure;

    -- Propagation delay
    constant T_PROP : time := 10 ns;

    -- Common register encodings used throughout
    constant R1 : std_logic_vector(4 downto 0) := "00001"; -- x1
    constant R2 : std_logic_vector(4 downto 0) := "00010"; -- x2
    constant R3 : std_logic_vector(4 downto 0) := "00011"; -- x3
    constant R0 : std_logic_vector(4 downto 0) := "00000"; -- x0

    -- Default/don't-care constants used when a field is irrelevant
    constant NO_REG : std_logic_vector(4 downto 0) := "00000";
    constant DC_IMM : std_logic_vector(31 downto 0) := (others => '0');
    constant DC_DOP : data_access_size_t  := DATA_BYTE;
    constant DC_BOP : std_logic_vector(2 downto 0)  := "000";

begin

    DUT: InstructionDecoder
        port map(
            inputInstruction => inputInstruction,
            registerAddress1 => registerAddress1,
            registerAddress2 => registerAddress2,
            destinationRegister => destinationRegister,
            wbEnabled => wbEnabled,
            immVal => immVal,
            alu_op1_mux_select => alu_op1_mux_select,
            alu_op2_mux_select => alu_op2_mux_select,
            alu_op => alu_op,
            muldiv_op => muldiv_op,
            branchOperation => branchOperation,
            branchEnabled => branchEnabled,
            dataOperation => dataOperation,
            dataAccessEnabled => dataAccessEnabled,
            dataReadNotWrite => dataReadNotWrite,
            wb_mux_select => wb_mux_select,
            muldivEnabled => muldivEnabled
        );

    test_proc: process
        variable instr : std_logic_vector(31 downto 0);
    begin

        -- ADD x3, x1, x2
        instr := encode_r("0000000", R2, R1, "000", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ADD", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SUB x3, x1, x2
        instr := encode_r("0100000", R2, R1, "000", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SUB", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_SUB, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SLL x3, x1, x2
        instr := encode_r("0000000", R2, R1, "001", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SLL", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_SLL, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SLT x3, x1, x2
        instr := encode_r("0000000", R2, R1, "010", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SLT", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_SLT, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SLTU x3, x1, x2
        instr := encode_r("0000000", R2, R1, "011", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SLTU", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_SLTU, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- XOR x3, x1, x2
        instr := encode_r("0000000", R2, R1, "100", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("XOR", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_XOR, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SRL x3, x1, x2
        instr := encode_r("0000000", R2, R1, "101", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SRL", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_SRL, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SRA x3, x1, x2
        instr := encode_r("0100000", R2, R1, "101", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SRA", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_SRA, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- OR x3, x1, x2
        instr := encode_r("0000000", R2, R1, "110", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("OR", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_OR, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- AND x3, x1, x2
        instr := encode_r("0000000", R2, R1, "111", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("AND", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_AND, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: ADD with rd=x0 (writes to zero register, wbEnabled still asserted by decoder)
        instr := encode_r("0000000", R2, R1, "000", R0, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ADD_rd_x0", instr,
            R1, R2, R0, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: SUB x0, x0, x0 (all-zero registers)
        instr := encode_r("0100000", R0, R0, "000", R0, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SUB_x0_x0_x0", instr,
            R0, R0, R0, '1', DC_IMM, "00", "00",
            ALU_SUB, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- MUL x3, x1, x2
        instr := encode_r("0000001", R2, R1, "000", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("MUL", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_MUL, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- MULH x3, x1, x2
        instr := encode_r("0000001", R2, R1, "001", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("MULH", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_MULH, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- MULHSU x3, x1, x2
        instr := encode_r("0000001", R2, R1, "010", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("MULHSU", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_MULHSU, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- MULHU x3, x1, x2
        instr := encode_r("0000001", R2, R1, "011", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("MULHU", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_MULHU, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- DIV x3, x1, x2
        instr := encode_r("0000001", R2, R1, "100", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("DIV", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_DIV, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- DIVU x3, x1, x2
        instr := encode_r("0000001", R2, R1, "101", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("DIVU", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_DIVU, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- REM x3, x1, x2
        instr := encode_r("0000001", R2, R1, "110", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("REM", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_REM, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- REMU x3, x1, x2
        instr := encode_r("0000001", R2, R1, "111", R3, OP_RTYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("REMU", instr,
            R1, R2, R3, '1', DC_IMM, "00", "00",
            ALU_ADD, MULDIV_REMU, '1', DC_BOP, '0', DC_DOP, '0', '0', "01",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- ADDI x3, x1, 5
        instr := encode_i("000000000101", R1, "000", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ADDI_pos", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- ADDI x3, x1, -1  (negative immediate, sign-extension check)
        instr := encode_i("111111111111", R1, "000", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ADDI_neg1", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- ADDI x3, x1, 2047  (maximum positive I-imm)
        instr := encode_i("011111111111", R1, "000", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ADDI_max_pos", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- ADDI x3, x1, -2048 (minimum negative I-imm)
        instr := encode_i("100000000000", R1, "000", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ADDI_min_neg", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SLTI x3, x1, 10
        instr := encode_i("000000001010", R1, "010", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SLTI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_SLT, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SLTIU x3, x1, 10
        instr := encode_i("000000001010", R1, "011", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SLTIU", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_SLTU, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- XORI x3, x1, 0xFF
        instr := encode_i("000011111111", R1, "100", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("XORI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_XOR, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- ORI x3, x1, 0x0F
        instr := encode_i("000000001111", R1, "110", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ORI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_OR, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- ANDI x3, x1, 0x0F
        instr := encode_i("000000001111", R1, "111", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("ANDI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_AND, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SLLI x3, x1, 4   (funct7=0000000, shamt=00100)
        instr := encode_i("000000000100", R1, "001", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SLLI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_SLL, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SRLI x3, x1, 4   (funct7=0000000)
        instr := encode_i("000000000100", R1, "101", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SRLI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_SRL, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SRAI x3, x1, 4   (funct7=0100000, bit 30 of instr = '1')
        instr := encode_i("010000000100", R1, "101", R3, OP_ITYPE);
        inputInstruction <= instr; wait for T_PROP;
        check("SRAI", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_SRA, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LB x3, 4(x1)
        instr := encode_i("000000000100", R1, "000", R3, OP_LOAD);
        inputInstruction <= instr; wait for T_PROP;
        check("LB", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_BYTE, '1', '1', "10",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LH x3, 4(x1)
        instr := encode_i("000000000100", R1, "001", R3, OP_LOAD);
        inputInstruction <= instr; wait for T_PROP;
        check("LH", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_HALF, '1', '1', "10",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LW x3, 4(x1)
        instr := encode_i("000000000100", R1, "010", R3, OP_LOAD);
        inputInstruction <= instr; wait for T_PROP;
        check("LW", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_WORD, '1', '1', "10",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LBU x3, 4(x1)
        instr := encode_i("000000000100", R1, "100", R3, OP_LOAD);
        inputInstruction <= instr; wait for T_PROP;
        check("LBU", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_UNSIGNED_BYTE, '1', '1', "10",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LHU x3, 4(x1)
        instr := encode_i("000000000100", R1, "101", R3, OP_LOAD);
        inputInstruction <= instr; wait for T_PROP;
        check("LHU", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_UNSIGNED_HALF, '1', '1', "10",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: LW with negative offset  LW x3, -4(x1)
        instr := encode_i("111111111100", R1, "010", R3, OP_LOAD);
        inputInstruction <= instr; wait for T_PROP;
        check("LW_neg_offset", instr,
            R1, NO_REG, R3, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_WORD, '1', '1', "10",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SB x2, 8(x1)
        instr := encode_s("000000001000", R2, R1, "000", OP_STORE);
        inputInstruction <= instr; wait for T_PROP;
        check("SB", instr,
            R1, R2, NO_REG, '0', imm_s(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_BYTE, '1', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SH x2, 8(x1)
        instr := encode_s("000000001000", R2, R1, "001", OP_STORE);
        inputInstruction <= instr; wait for T_PROP;
        check("SH", instr,
            R1, R2, NO_REG, '0', imm_s(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_HALF, '1', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- SW x2, 8(x1)
        instr := encode_s("000000001000", R2, R1, "010", OP_STORE);
        inputInstruction <= instr; wait for T_PROP;
        check("SW", instr,
            R1, R2, NO_REG, '0', imm_s(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_WORD, '1', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: SW with negative offset  SW x2, -8(x1)
        instr := encode_s("111111111000", R2, R1, "010", OP_STORE);
        inputInstruction <= instr; wait for T_PROP;
        check("SW_neg_offset", instr,
            R1, R2, NO_REG, '0', imm_s(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_WORD, '1', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: SW maximum positive S-immediate (+2047 split across imm[11:5] | imm[4:0])
        instr := encode_s("011111111111", R2, R1, "010", OP_STORE);
        inputInstruction <= instr; wait for T_PROP;
        check("SW_max_pos_offset", instr,
            R1, R2, NO_REG, '0', imm_s(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DATA_WORD, '1', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- BEQ x1, x2, +8   imm13 = 0_000_0000_1000 (= +8, i.e. imm[12:0] with bit0=0)
        instr := encode_b("0000000001000", R2, R1, "000", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BEQ", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "000", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- BNE x1, x2, +8
        instr := encode_b("0000000001000", R2, R1, "001", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BNE", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "001", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- BLT x1, x2, +8
        instr := encode_b("0000000001000", R2, R1, "100", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BLT", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "100", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- BGE x1, x2, +8
        instr := encode_b("0000000001000", R2, R1, "101", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BGE", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "101", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- BLTU x1, x2, +8
        instr := encode_b("0000000001000", R2, R1, "110", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BLTU", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "110", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- BGEU x1, x2, +8
        instr := encode_b("0000000001000", R2, R1, "111", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BGEU", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "111", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: BEQ with negative offset (backward branch)  imm = -8 => 1_111_1111_1000
        instr := encode_b("1111111111000", R2, R1, "000", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BEQ_neg_offset", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "000", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: BEQ maximum positive B-offset (+4094)
        instr := encode_b("0111111111110", R2, R1, "000", OP_BRANCH);
        inputInstruction <= instr; wait for T_PROP;
        check("BEQ_max_pos", instr,
            R1, R2, NO_REG, '0', imm_b(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', "000", '1', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- JAL x1, +16  imm21 = 0_0000000_0_00000010000 (= +16)
        instr := encode_j("000000000000000010000", R1, OP_JAL);
        inputInstruction <= instr; wait for T_PROP;
        check("JAL_pos", instr,
            NO_REG, NO_REG, R1, '1', imm_j(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "11",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- JAL x0, -4  (infinite loop / discard link)  imm21 all 1s except bit1 = 1
        instr := encode_j("111111111111111111100", R0, OP_JAL);
        inputInstruction <= instr; wait for T_PROP;
        check("JAL_neg_x0", instr,
            NO_REG, NO_REG, R0, '1', imm_j(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "11",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- Edge: JAL maximum positive offset (+1048574)
        instr := encode_j("011111111111111111110", R1, OP_JAL);
        inputInstruction <= instr; wait for T_PROP;
        check("JAL_max_pos", instr,
            NO_REG, NO_REG, R1, '1', imm_j(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "11",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- JALR x1, x2, 4
        instr := encode_i("000000000100", R2, "000", R1, OP_JALR);
        inputInstruction <= instr; wait for T_PROP;
        check("JALR_pos", instr,
            R2, NO_REG, R1, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "11",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- JALR x0, x1, 0  (return / RET pseudo-instruction)
        instr := encode_i("000000000000", R1, "000", R0, OP_JALR);
        inputInstruction <= instr; wait for T_PROP;
        check("JALR_ret", instr,
            R1, NO_REG, R0, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "11",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- JALR with negative offset  JALR x1, x2, -4
        instr := encode_i("111111111100", R2, "000", R1, OP_JALR);
        inputInstruction <= instr; wait for T_PROP;
        check("JALR_neg", instr,
            R2, NO_REG, R1, '1', imm_i(instr), "00", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "11",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LUI x3, 0xABCDE
        instr := encode_u("10101011110011011110", R3, OP_LUI);
        inputInstruction <= instr; wait for T_PROP;
        check("LUI", instr,
            NO_REG, NO_REG, R3, '1', imm_u(instr), "00", "01",
            ALU_LUI, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LUI x0, 0x00001  (load into zero register)
        instr := encode_u("00000000000000000001", R0, OP_LUI);
        inputInstruction <= instr; wait for T_PROP;
        check("LUI_x0", instr,
            NO_REG, NO_REG, R0, '1', imm_u(instr), "00", "01",
            ALU_LUI, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- LUI all-ones immediate (maximum U-imm)
        instr := encode_u("11111111111111111111", R3, OP_LUI);
        inputInstruction <= instr; wait for T_PROP;
        check("LUI_max", instr,
            NO_REG, NO_REG, R3, '1', imm_u(instr), "00", "01",
            ALU_LUI, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- AUIPC x3, 0x12345
        instr := encode_u("00010010001101000101", R3, OP_AUIPC);
        inputInstruction <= instr; wait for T_PROP;
        check("AUIPC", instr,
            NO_REG, NO_REG, R3, '1', imm_u(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        -- AUIPC x0, 0xFFFFF (all-ones, negative U-imm)
        instr := encode_u("11111111111111111111", R0, OP_AUIPC);
        inputInstruction <= instr; wait for T_PROP;
        check("AUIPC_max_neg", instr,
            NO_REG, NO_REG, R0, '1', imm_u(instr), "01", "01",
            ALU_ADD, MULDIV_MUL, '0', DC_BOP, '0', DC_DOP, '0', '0', "00",
            registerAddress1, registerAddress2, destinationRegister, wbEnabled, immVal,
            alu_op1_mux_select, alu_op2_mux_select,
            alu_op, muldiv_op, muldivEnabled,
            branchOperation, branchEnabled,
            dataOperation, dataAccessEnabled, dataReadNotWrite,
            wb_mux_select, fail_count);

        if fail_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "FAILURES: " & integer'image(fail_count) severity error;
        end if;

        wait;
    end process;

end architecture;