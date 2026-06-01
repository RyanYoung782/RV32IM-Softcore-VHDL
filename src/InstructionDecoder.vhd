library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_constants.all;

entity InstructionDecoder is
	port(
		inputInstruction: in std_logic_vector(31 downto 0);
		
		--Register File Addresses (31 downto 0)
		registerAddress1: out std_logic_vector(4 downto 0);
		registerAddress2: out std_logic_vector(4 downto 0);
		destinationRegister: out std_logic_vector(4 downto 0);
		wbEnabled: out std_logic;
		
		--Immediate selection
		immVal : out std_logic_vector(31 downto 0);
		
		--EX Stage MUXes that help with operand selection and forwarding of values
		alu_op1_mux_select: out std_logic_vector(1 downto 0);
		alu_op2_mux_select: out std_logic_vector(1 downto 0);
		
		--Operation selection for the ALU and muldiv unit
		alu_op: out alu_op_t;
		muldiv_op: out muldiv_op_t;
		
		--Branching Signals
		branchOperation: out std_logic_vector(2 downto 0);
		branchEnabled: out std_logic;
		
		--Data Access Signals
		dataOperation: out data_access_size_t;
		dataAccessEnabled: out std_logic;
		dataReadNotWrite: out std_logic;
		
		--WB stage signals
		wb_mux_select: out std_logic_vector(1 downto 0);	
		--For the HazardDetectionUnit to check which operation is firing
		--If muldivEnabled = '1', muldiv Operation, else alu Operation
		muldivEnabled : out std_logic
	);
end InstructionDecoder;

architecture rtl of InstructionDecoder is
	
begin
	
	--process block for decoding instructions
	process(inputInstruction)
		--Extractable common fields:
		variable funct7: std_logic_vector(6 downto 0);
		variable rs2: std_logic_vector(4 downto 0);
		variable rs1: std_logic_vector(4 downto 0);
		variable funct3: std_logic_vector(2 downto 0);
		variable rd: std_logic_vector(4 downto 0);
		variable opcode: std_logic_vector(6 downto 0);
	begin
		--Extract all common fields
		funct7 := inputInstruction(31 downto 25);
		rs2 := inputInstruction(24 downto 20);
		rs1 := inputInstruction(19 downto 15);
		funct3 := inputInstruction(14 downto 12);
		rd := inputInstruction(11 downto 7);
		opcode := inputInstruction(6 downto 0);
		
		--default vals
		registerAddress1 <= "00000";
		registerAddress2 <= "00000";
		destinationRegister <= "00000";
		wbEnabled <= '0';
		immVal <= (others => '0');
		alu_op1_mux_select <= "00";
		alu_op2_mux_select <= "00";
		alu_op <= ALU_ADD;
		muldiv_op <= MULDIV_MUL;
		muldivEnabled <= '0';
		branchOperation <= "000";
		branchEnabled <= '0';
		dataOperation <= DATA_BYTE;
		dataAccessEnabled <= '0';
		dataReadNotWrite <= '0';
		wb_mux_select <= "00";
		
		--Sequential to figure out operation format
		case opcode is

			when OP_RTYPE =>--0110011
				registerAddress1 <= rs1;
				registerAddress2 <= rs2;
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op1_mux_select <= "00";-- operand A = rs1
				alu_op2_mux_select <= "00";-- operand B = rs2
				immVal <= (others => '0');  -- dont care, no immediate used
				-- Check if M extension instruction
				if funct7 = "0000001" then
					--Enable the unit to be used
					muldivEnabled <= '1';
					wb_mux_select <= "01"; -- writeback = muldiv result
					--MULDIV instruction selection
					case funct3 is
						when "000" => muldiv_op <= MULDIV_MUL;
						when "001" => muldiv_op <= MULDIV_MULH;
						when "010" => muldiv_op <= MULDIV_MULHSU;
						when "011" => muldiv_op <= MULDIV_MULHU;
						when "100" => muldiv_op <= MULDIV_DIV;
						when "101" => muldiv_op <= MULDIV_DIVU;
						when "110" => muldiv_op <= MULDIV_REM;
						when "111" => muldiv_op <= MULDIV_REMU;
						when others => null;
					end case;
				else
					wb_mux_select <= "00"; -- writeback = ALU result
					--Standard R-type ALU operation
					case funct3 is
						when "000" =>
							if funct7(5) = '0' then
								alu_op <= ALU_ADD;
							else
								alu_op <= ALU_SUB;
							end if;
						when "001" => alu_op <= ALU_SLL;
						when "010" => alu_op <= ALU_SLT;
						when "011" => alu_op <= ALU_SLTU;
						when "100" => alu_op <= ALU_XOR;
						when "101" =>
							if funct7(5) = '0' then
								alu_op <= ALU_SRL;
							else
								alu_op <= ALU_SRA;
							end if;
						when "110" => alu_op <= ALU_OR;
						when "111" => alu_op <= ALU_AND;
						when others => null;
					end case;
				end if;

			when OP_ITYPE => --0010011
				registerAddress1 <= rs1;
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op1_mux_select <= "00";  -- operand A = rs1
				alu_op2_mux_select <= "01";  -- operand B = immediate
				wb_mux_select <= "00"; -- writeback = ALU result
				-- bits [31:20], sign extended
				immVal <= (31 downto 12 => inputInstruction(31)) 
					 & inputInstruction(31 downto 20);
				case funct3 is
					when "000" => 
						alu_op <= ALU_ADD; -- ADDI
					when "001" => 
						alu_op <= ALU_SLL; -- SLLI
					when "010" => 
						alu_op <= ALU_SLT; -- SLTI
					when "011" => 
						alu_op <= ALU_SLTU; -- SLTIU
					when "100" => 
						alu_op <= ALU_XOR; -- XORI
					when "101" =>
						if funct7(5) = '0' then
							alu_op <= ALU_SRL; -- SRLI
						else
							alu_op <= ALU_SRA; -- SRAI
						end if;
					when "110" => 
						alu_op <= ALU_OR; --ORI
					when "111" => 
						alu_op <= ALU_AND; --ANDI
					when others => 
						alu_op <= ALU_AND; --Least harmful op to default to 
				end case;

			when OP_LOAD => --0000011
				registerAddress1 <= rs1;
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op1_mux_select <= "00"; --operand A = rs1
				alu_op2_mux_select <= "01"; --operand B = immediate (offset)
				alu_op <= ALU_ADD;
				dataAccessEnabled <= '1';
				dataReadNotWrite<= '1'; --read
				wb_mux_select <= "10"; --writeback = data memory output
				-- bits [31:20], sign extended
				immVal <= (31 downto 12 => inputInstruction(31)) 
					 & inputInstruction(31 downto 20);
				--funct3 defines which data operation we tell the data cache to use
				--LB=000 LH=001 LW=010 LBU=100 LHU=101
				case funct3 is
					when "000" => 
						dataOperation <= DATA_BYTE;
					when "001" =>
						dataOperation <= DATA_HALF;
					when "010" =>
						dataOperation <= DATA_WORD;
					when "100" =>
						dataOperation <= DATA_UNSIGNED_BYTE;
					when "101" =>
						dataOperation <= DATA_UNSIGNED_HALF;
					when others =>
						dataOperation <= DATA_BYTE;
				end case;

			when OP_STORE =>  --0100011
				registerAddress1 <= rs1;
				registerAddress2 <= rs2;
				wbEnabled <= '0';  --stores do not write to register file
				alu_op1_mux_select <= "00";  --operand A = rs1
				alu_op2_mux_select <= "01";  --operand B = immediate (offset)
				alu_op <= ALU_ADD;
				dataAccessEnabled <= '1';
				dataReadNotWrite <= '0';  --write
				wb_mux_select <= "00";  --dont care, wbEnabled = 0
				-- bits [31:25] | [11:7], sign extended
				immVal <= (31 downto 12 => inputInstruction(31))
					 & inputInstruction(31 downto 25)
					 & inputInstruction(11 downto 7);
				--funct3 defines data operation we tell the cache to write with
				--SB=000 SH=001 SW=010
				case funct3 is
					when "000" => 
						dataOperation <= DATA_BYTE;
					when "001" =>
						dataOperation <= DATA_HALF;
					when "010" =>
						dataOperation <= DATA_WORD;
					when others =>
						dataOperation <= DATA_BYTE;
				end case;

			when OP_BRANCH => --1100011
				registerAddress1<= rs1;
				registerAddress2<= rs2;
				wbEnabled <= '0';  --branches do not write to register file
				alu_op1_mux_select <= "01";  --operand A = PC (branch target = PC + imm)
				alu_op2_mux_select <= "01";  --operand B = immediate
				alu_op<= ALU_ADD;
				branchEnabled <= '1';
				branchOperation <= funct3;  --BEQ=000 BNE=001 BLT=100 BGE=101 BLTU=110 BGEU=111
				wb_mux_select <= "00";  --dont care, wbEnabled = 0
				immVal <= (31 downto 13 => inputInstruction(31))
					 & inputInstruction(31)
					 & inputInstruction(7)
					 & inputInstruction(30 downto 25)
					 & inputInstruction(11 downto 8)
					 & '0';

			when OP_JAL =>  --1101111
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op1_mux_select <= "01";  --operand A = PC (target = PC + imm)
				alu_op2_mux_select <= "01";  --operand B = immediate
				alu_op <= ALU_ADD;
				wb_mux_select <= "11";  --writeback = PC + 4 (link address)
				-- bits [31][19:12][20][30:21], LSB always 0
				immVal <= (31 downto 21 => inputInstruction(31))
					 & inputInstruction(31)
					 & inputInstruction(19 downto 12)
					 & inputInstruction(20)
					 & inputInstruction(30 downto 21)
					 & '0';

			when OP_JALR => --1100111
				registerAddress1 <= rs1;
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op1_mux_select <= "00";  --operand A = rs1 (target = rs1 + imm)
				alu_op2_mux_select <= "01";  --operand B = immediate
				alu_op <= ALU_ADD;
				wb_mux_select <= "11";  --writeback = PC + 4 (link address)
				-- bits [31:20], sign extended
				immVal <= (31 downto 12 => inputInstruction(31)) 
					 & inputInstruction(31 downto 20);

			when OP_LUI =>  --0110111
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op <= ALU_LUI;
				alu_op1_mux_select <= "00";  --operand A => DONT CARE
				alu_op2_mux_select <= "01";  -- operand B = immediate (upper immediate)
				wb_mux_select <= "00"; -- writeback = ALU result
				-- bits [31:12], lower 12 zeroed
				immVal <= inputInstruction(31 downto 12) 
					 & (11 downto 0 => '0');

			when OP_AUIPC =>--0010111
				destinationRegister <= rd;
				wbEnabled <= '1';
				alu_op1_mux_select<= "01";-- operand A = PC
				alu_op2_mux_select<= "01";-- operand B = immediate
				alu_op<= ALU_ADD;
				wb_mux_select <= "00"; -- writeback = ALU result
				-- bits [31:12], lower 12 zeroed
				immVal <= inputInstruction(31 downto 12) 
					 & (11 downto 0 => '0');

			when others => null;
		end case;
	end process;

end architecture;
