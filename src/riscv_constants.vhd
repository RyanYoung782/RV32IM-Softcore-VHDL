package riscv_constants is

    -- Opcodes
    constant OP_RTYPE  : std_logic_vector(6 downto 0) := "0110011";
    constant OP_ITYPE  : std_logic_vector(6 downto 0) := "0010011";
    constant OP_LOAD   : std_logic_vector(6 downto 0) := "0000011";
    constant OP_STORE  : std_logic_vector(6 downto 0) := "0100011";
    constant OP_BRANCH : std_logic_vector(6 downto 0) := "1100011";
    constant OP_JAL    : std_logic_vector(6 downto 0) := "1101111";
    constant OP_JALR   : std_logic_vector(6 downto 0) := "1100111";
    constant OP_LUI    : std_logic_vector(6 downto 0) := "0110111";
    constant OP_AUIPC  : std_logic_vector(6 downto 0) := "0010111";

    -- ALU operations
    type alu_op_t is (
        ALU_ADD, ALU_SUB, ALU_AND, ALU_OR,  ALU_XOR,
        ALU_SLL, ALU_SRL, ALU_SRA, ALU_SLT, ALU_SLTU,
        ALU_LUI, ALU_AUIPC
    );
	
	--M extension operations
	type muldiv_op_t is (
		MULDIV_MUL, MULDIV_MULH, MULDIV_MULHSU, MULDIV_MULHU,
		MULDIV_DIV, MULDIV_DIVU,
		MULDIV_REM, MULDIV_REMU
	);

    -- Immediate formats
    type imm_sel_t is (
		IMM_I, IMM_S, IMM_B, IMM_U, IMM_J
	);
	
	--Load Store size formats
	type data_access_size_t (
		DATA_BYTE, DATA_HALF, DATA_WORD, DATA_UNSIGNED_BYTE, DATA_UNSIGNED_HALF
	);

end package;