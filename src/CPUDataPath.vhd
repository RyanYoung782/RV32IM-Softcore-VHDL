library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity CPUDataPath is
	port(
		--Input Clock Signal
		clk : in std_logic;
		reset : in std_logic;
		
		--Instruction Cache Interface
		ICacheCurrAddress : out std_logic_vector(31 downto 0);
		ICacheCurrInstruction : in std_logic_vector(31 downto 0);
		
		--Data access signals 
		DCacheUseEnabled : out std_logic;
		
		--MMIO access signals
		MMIOUseEnabled : out std_logic;
		
		--Shared MEM stage signals
		DataOperation : out data_access_size_t;
		ReadNotWrite : out std_logic;
		DataAddress : out std_logic_vector(31 downto 0);
		writedata : out std_logic_vector(31 downto 0);
		readdata : in std_logic_vector(31 downto 0)
	);
end CPUDataPath;

architecture rtl of CPUDataPath is
	
	--IFID Pipeline Register
	signal ifid_currAddress : std_logic_vector(31 downto 0);
	signal ifid_nextAddress : std_logic_vector(31 downto 0);
	signal ifid_currInstruction: std_logic_vector(31 downto 0);
	
	--IDEX Pipeline Register
	signal idex_branchCondition : std_logic_vector(2 downto 0);
	signal idex_branchEnabled : std_logic;
	signal idex_currAddress : std_logic_vector(31 downto 0);
	signal idex_nextAddress : std_logic_vector(31 downto 0);
	signal idex_rs1 : std_logic_vector(4 downto 0);
	signal idex_rs2 : std_logic_vector(4 downto 0);
	signal idex_rs1_data : std_logic_vector(31 downto 0);
	signal idex_rs2_data : std_logic_vector(31 downto 0);
	signal idex_operand1MUXSelect : std_logic;
	signal idex_operand2MUXSelect : std_logic;
	signal idex_alu_op : alu_op_t;
	signal idex_muldiv_op : muldiv_op_t;
	signal idex_muldivEnabled : std_logic;
	signal idex_rd : std_logic_vector(4 downto 0);
	signal idex_wbEnabled : std_logic;
	signal idex_immVal : std_logic_vector(31 downto 0);
	signal idex_dataEnabled : std_logic;
	signal idex_dataReadNotWrite : std_logic;
	signal idex_dataOperation : data_access_size_t;
	signal idex_wbMUXSelect : std_logic_vector(1 downto 0);
	
	--EXMEM Pipeline Register
	signal exmem_nextAddress : std_logic_vector(31 downto 0);
	signal exmem_ALUOutput : std_logic_vector(31 downto 0);
	signal exmem_muldivOutput : std_logic_vector(31 downto 0);
	signal exmem_dataEnabled : std_logic;
	signal exmem_dataReadNotWrite : std_logic;
	signal exmem_dataOperation : data_access_size_t;
	signal exmem_rd : std_logic_vector(4 downto 0);
	signal exmem_wbEnabled : std_logic;
	signal exmem_wbMUXSelect : std_logic_vector(1 downto 0);
	signal exmem_rs2_data : std_logic_vector(31 downto 0);
	
	--MEMWB Pipeline Register
	signal memwb_nextAddress : std_logic_vector(31 downto 0);
	signal memwb_readData : std_logic_vector(31 downto 0);
	signal memwb_ALUOutput : std_logic_vector(31 downto 0);
	signal memwb_muldivOutput : std_logic_vector(31 downto 0);
	signal memwb_rd : std_logic_vector(4 downto 0);
	signal memwb_wbEnabled : std_logic;
	signal memwb_wbMUXSelect : std_logic_vector(1 downto 0);
	
	--Component Declarations
	component BranchingUnit is
		port(
			rs1_data : in std_logic_vector(31 downto 0);
			rs2_data : in std_logic_vector(31 downto 0);
			branch_op : in std_logic_vector(2  downto 0);
			branch : in std_logic;
			
			branch_taken : out std_logic
		);
	end component BranchingUnit;
	
	component ForwardingUnit is
		port(
			idex_rs1 : in std_logic_vector(4 downto 0);
			idex_rs2 : in std_logic_vector(4 downto 0);		
			exmem_rd : in std_logic_vector(4 downto 0);
			memwb_rd : in std_logic_vector(4 downto 0);
			
			rs1MUXSelect : out std_logic_vector(1 downto 0);
			rs2MUXSelect : out std_logic_vector(1 downto 0)
		);
	end component ForwardingUnit;
	
	component HazardDetectionUnit is
		port(
			idRs1: in std_logic_vector(4 downto 0);
			idRs2: in std_logic_vector(4 downto 0);
			branch_taken: in std_logic;
			idex_dataEnabled : in std_logic;
			idex_dataReadNotWrite : in std_logic;
			idex_rd : in std_logic_vector(4 downto 0);
			muldivBusy: in std_logic;
			muldivResultValid: in std_logic;
			
			ifid_flush: out std_logic;
			idex_flush: out std_logic;
			pc_stall: out std_logic;
			ifid_stall: out std_logic;
			idex_stall: out std_logic
		);
	end component HazardDetectionUnit;
	
	component InstructionDecoder is 
		port(
			inputInstruction: in std_logic_vector(31 downto 0);
			
			registerAddress1: out std_logic_vector(4 downto 0);
			registerAddress2: out std_logic_vector(4 downto 0);
			destinationRegister: out std_logic_vector(4 downto 0);
			wbEnabled: out std_logic;
			immVal : out std_logic_vector(31 downto 0);
			alu_op1_mux_select: out std_logic;
			alu_op2_mux_select: out std_logic;
			alu_op: out alu_op_t;
			muldiv_op: out muldiv_op_t;
			branchOperation: out std_logic_vector(2 downto 0);
			branchEnabled: out std_logic;
			dataOperation: out data_access_size_t;
			dataAccessEnabled: out std_logic;
			dataReadNotWrite: out std_logic;
			wb_mux_select: out std_logic_vector(1 downto 0);	
			muldivEnabled : out std_logic
		);
	end component InstructionDecoder;
	
	component IntegerALU is
		port(
			alu_op : in alu_op_t;
			rs1 : in std_logic_vector(31 downto 0);
			rs2 : in std_logic_vector(31 downto 0);
			
			result : out std_logic_vector(31 downto 0)		
		);
	end component IntegerALU;
	
	component MuldivUnit is 
		port(
			clk: in std_logic;
			reset: in std_logic;
			operand1: in std_logic_vector(31 downto 0);
			operand2: in std_logic_vector(31 downto 0);
			muldiv_op: in muldiv_op_t;
			muldivEnabled: in std_logic;
			
			muldivBusy: out std_logic;
			muldivResultValid: out std_logic;
			output: out std_logic_vector(31 downto 0)
		);
	end component MuldivUnit;
	
	component ProgramCounter is
		port(
			clk : in std_logic;
			reset : in std_logic;
			stall : in std_logic;
			branch_taken : in std_logic;
			branch_addr : in std_logic_vector(31 downto 0);
			
			pc : out std_logic_vector(31 downto 0);
			pc_plus_4 : out std_logic_vector(31 downto 0)
		);
	end component ProgramCounter;
	
	component RegisterFile is
		port(
			clk : in std_logic;
			reset : in std_logic;
			reg_write : in std_logic;
			rd_addr : in std_logic_vector(4 downto 0);
			write_data : in std_logic_vector(31 downto 0);
			rs1_addr : in std_logic_vector(4 downto 0);
			rs2_addr : in std_logic_vector(4 downto 0);
			
			rs1_data : out std_logic_vector(31 downto 0);
			rs2_data : out std_logic_vector(31 downto 0)
		);
	end component RegisterFile;
	
	component AddressDecoder is
		port(
			dataAddress : in std_logic_vector(31 downto 0);
			dataEnabled : in std_logic;
			dmem_sel : out std_logic;
			mmio_sel : out std_logic
		);
	end component AddressDecoder;
	
	--Component Output Wires!
	signal branch_taken : std_logic;
	
	signal rs1MUXSelect : std_logic_vector(1 downto 0);
	signal rs2MUXSelect : std_logic_vector(1 downto 0);
	signal branchOperand1MUXSelect : std_logic_vector(1 downto 0);
	signal branchOperand2MUXSelect : std_logic_vector(1 downto 0);
	
	signal ifid_flush: std_logic;
	signal idex_flush: std_logic;
	signal pc_stall: std_logic;
	signal ifid_stall: std_logic;
	signal idex_stall: std_logic;
	
	signal registerAddress1: std_logic_vector(4 downto 0);
	signal registerAddress2: std_logic_vector(4 downto 0);
	signal destinationRegister: std_logic_vector(4 downto 0);
	signal wbEnabled: std_logic;
	signal immVal : std_logic_vector(31 downto 0);
	signal alu_op1_mux_select: std_logic;
	signal alu_op2_mux_select: std_logic;
	signal alu_op: alu_op_t;
	signal muldiv_op: muldiv_op_t;
	signal branchOperation: std_logic_vector(2 downto 0);
	signal branchEnabled: std_logic;
	signal dataOperation: data_access_size_t;
	signal dataAccessEnabled: std_logic;
	signal dataReadNotWrite: std_logic;
	signal wb_mux_select: std_logic_vector(1 downto 0);	
	signal muldivEnabled : std_logic;
	
	signal result : std_logic_vector(31 downto 0);	
	
	signal muldivBusy: std_logic;
	signal muldivResultValid: std_logic;
	signal output: std_logic_vector(31 downto 0);
	
	signal pc : std_logic_vector(31 downto 0);
	signal pc_plus_4 : std_logic_vector(31 downto 0);
	
	signal rs1_data : std_logic_vector(31 downto 0);
	signal rs2_data : std_logic_vector(31 downto 0);
	
	--Internal MUX Output Wires
	
	--Output Signal of RegFile vs EX-EX vs MEM-EX forwarding MUX
	signal rs1MUXOutput : std_logic_vector(31 downto 0);
	signal rs2MUXOutput : std_logic_vector(31 downto 0);
	
	--Output Signal of RegFile vs PC MUX
	signal operand1MUXOutput : std_logic_vector(31 downto 0);
	signal operand2MUXOutput : std_logic_vector(31 downto 0);
	
	--EX-EX Forwarding MUX Output
	signal EXForwardMUXOutput : std_logic_vector(31 downto 0);
	
	--MEM-EX Forwarding MUX output
	signal MEMForwardMUXOutput : std_logic_vector(31 downto 0);
	
	--WB MUX Output
	signal wbMUXOutput : std_logic_vector(31 downto 0);
			
begin
	--Component Instantiations
	BranchingUnitInstance : BranchingUnit
		port map(
			rs1_data => rs1MUXOutput,
			rs2_data => rs2MUXOutput,
			branch_op => idex_branchCondition,
			branch => idex_branchEnabled,
			branch_taken => branch_taken
		);
	
	ForwardingUnitInstance : ForwardingUnit
		port map(
			idex_rs1 => idex_rs1,
			idex_rs2 => idex_rs2,
			exmem_rd => exmem_rd,
			memwb_rd => memwb_rd,
			rs1MUXSelect => rs1MUXSelect,
			rs2MUXSelect => rs2MUXSelect
		);
		
	HazardDetectionUnitInstance : HazardDetectionUnit
		port map(
			idRs1 => registerAddress1,
			idRs2 => registerAddress2,
			branch_taken => branch_taken,
			idex_dataEnabled => idex_dataEnabled,
			idex_dataReadNotWrite => idex_dataReadNotWrite,
			idex_rd => idex_rd,
			muldivBusy => muldivBusy,
			muldivResultValid => muldivResultValid,
			ifid_flush => ifid_flush,
			idex_flush => idex_flush, 
			pc_stall => pc_stall,
			ifid_stall => ifid_stall,
			idex_stall => idex_stall
		);
		
	InstructionDecoderInstance : InstructionDecoder
		port map(
			inputInstruction => ifid_currInstruction,
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
		
	IntegerALUInstance : IntegerALU
		port map(
			alu_op => idex_alu_op,
			rs1 => operand1MUXOutput,
			rs2 => operand2MUXOutput,
			result => result
		);
		
	MuldivUnitInstance : MuldivUnit
		port map(
			clk => clk,
			reset => reset,
			operand1 => operand1MUXOutput,
			operand2 => operand2MUXOutput,
			muldiv_op => idex_muldiv_op,
			muldivEnabled => idex_muldivEnabled,
			muldivBusy => muldivBusy,
			muldivResultValid => muldivResultValid,
			output => output
		);
		
	ProgramCounterInstance : ProgramCounter
		port map(
			clk => clk,
			reset => reset,
			stall => pc_stall,
			branch_taken => branch_taken,
			branch_addr => result,
			pc => pc,
			pc_plus_4 => pc_plus_4
		);
	
	RegisterFileInstance : RegisterFile
		port map(
			clk => clk,
			reset => reset,
			reg_write => memwb_wbEnabled,
			rd_addr => memwb_rd,
			write_data => wbMUXOutput,
			rs1_addr => registerAddress1,
			rs2_addr => registerAddress2,
			rs1_data => rs1_data,
			rs2_data => rs2_data
		);
		
	AddressDecoderInstance : AddressDecoder
		port map(
			dataAddress => exmem_ALUOutput,
			dataEnabled => exmem_dataEnabled,
			dmem_sel => DCacheUseEnabled,
			mmio_sel => MMIOUseEnabled
		);
		
	--MUX Instantiations.
	
	--rs1 Selection 
	with rs1MUXSelect select rs1MUXOutput <=
		idex_rs1_data when "00",
		EXForwardMUXOutput when "10",
		MEMForwardMUXOutput when "11",
		(others => '0') when others;
	
	--rs2 Selection
	with rs2MUXSelect select rs2MUXOutput <=
		idex_rs2_data when "00",
		EXForwardMUXOutput when "10",
		MEMForwardMUXOutput when "11",
		(others => '0') when others;
		
	--Operand 1 Selection
	with idex_operand1MUXSelect select operand1MUXOutput <=
		rs1MUXOutput when '0',
		idex_currAddress when '1',
		(others => '0') when others;
		
	--Operand 2 Selection
	with idex_operand2MUXSelect select operand2MUXOutput <=
		rs2MUXOutput when '0',
		idex_immVal when '1',
		(others => '0') when others;
		
	--EX-EX Forwarding MUX
	with exmem_wbMUXSelect select EXForwardMUXOutput <=
		exmem_ALUOutput when "00",
		exmem_muldivOutput when "01",
		exmem_nextAddress when "11",
		(others => '0') when others;
	
	--MEM-EX Forwarding MUX
	with memwb_wbMUXSelect select MEMForwardMUXOutput <= 
		memwb_ALUOutput when "00",
		memwb_muldivOutput when "01",
		memwb_readData when "10",
		memwb_nextAddress when "11",
		(others => '0') when others;
	
	--WB Selection MUX
	with memwb_wbMUXSelect select wbMUXOutput <= 
		memwb_ALUOutput when "00",
		memwb_muldivOutput when "01",
		memwb_readData when "10",
		memwb_nextAddress when "11",
		(others => '0') when others;
		
	--Pipeline register clocked processes
	IFID_Register_proc: process(clk)
	begin
		if rising_edge(clk) then
			--Flushing and resets do the same thing: Insert NOP
			if reset = '1' or ifid_flush = '1' then
				ifid_currAddress <= x"00000000";
				ifid_nextAddress <= x"00000000";
				ifid_currInstruction <= x"00000000";
			elsif ifid_stall = '1' then --Maintain same value
				null;
			else --Update pipeline regs
				ifid_currAddress <= pc;
				ifid_nextAddress <= pc_plus_4;
				ifid_currInstruction <= ICacheCurrInstruction;
			end if;
		end if;
	end process;
	
	IDEX_Register_proc: process(clk)
	begin
		--Flushing and resets do the same thing: Insert NOP
		if rising_edge(clk) then
			if reset = '1' or idex_flush = '1' then
				idex_branchCondition <= "000";
				idex_branchEnabled <= '0';
				idex_currAddress <= x"00000000";
				idex_nextAddress <= x"00000000";
				idex_rs1 <= "00000";
				idex_rs2 <= "00000";
				idex_rs1_data <= x"00000000";
				idex_rs2_data <= x"00000000";
				idex_operand1MUXSelect <= '0';
				idex_operand2MUXSelect <= '0';
				idex_alu_op <= ALU_ADD;
				idex_muldiv_op <= MULDIV_MUL;
				idex_muldivEnabled <= '0';
				idex_rd <= "00000";
				idex_wbEnabled <= '0';
				idex_immVal <= x"00000000";
				idex_dataEnabled <= '0';
				idex_dataReadNotWrite <= '0';
				idex_dataOperation <= DATA_BYTE;
				idex_wbMUXSelect <= "00";
				
			elsif idex_stall = '1' then --Maintain values
				null;
				
			else --Update pipeline regs
				idex_branchCondition <= branchOperation;
				idex_branchEnabled <= branchEnabled;
				idex_currAddress <= ifid_currAddress;
				idex_nextAddress <= ifid_nextAddress;
				idex_rs1 <= registerAddress1;
				idex_rs2 <= registerAddress2;
				idex_rs1_data <= rs1_data;
				idex_rs2_data <= rs2_data;
				idex_operand1MUXSelect <= alu_op1_mux_select;
				idex_operand2MUXSelect <= alu_op2_mux_select;
				idex_alu_op <= alu_op;
				idex_muldiv_op <= muldiv_op;
				idex_muldivEnabled <= muldivEnabled;
				idex_rd <= destinationRegister;
				idex_wbEnabled <= wbEnabled;
				idex_immVal <= immVal;
				idex_dataEnabled <= dataAccessEnabled;
				idex_dataReadNotWrite <= dataReadNotWrite;
				idex_dataOperation <= dataOperation;
				idex_wbMUXSelect <= wb_mux_select;
				
			end if;
		end if;
	end process;
	
	EXMEM_Register_proc: process(clk)
	begin
		if rising_edge(clk) then
			--Insert NOP
			if reset = '1' then
				exmem_nextAddress <= x"00000000";
				exmem_ALUOutput <= x"00000000";
				exmem_muldivOutput <= x"00000000";
				exmem_dataEnabled <= '0';
				exmem_dataReadNotWrite <= '0';
				exmem_dataOperation <= DATA_BYTE;
				exmem_rd <= "00000";
				exmem_wbEnabled <= '0';
				exmem_wbMUXSelect <= "00";
				exmem_rs2_data <= x"00000000";
				
			else --Update pipeline regs
				exmem_nextAddress <= idex_nextAddress;
				exmem_ALUOutput <= result;
				exmem_muldivOutput <= output;
				exmem_dataEnabled <= idex_dataEnabled;
				exmem_dataReadNotWrite <= idex_dataReadNotWrite;
				exmem_dataOperation <= idex_dataOperation;
				exmem_rd <= idex_rd;
				exmem_wbEnabled <= idex_wbEnabled;
				exmem_wbMUXSelect <= idex_wbMUXSelect;
				exmem_rs2_data <= rs2MUXOutput;
				
			end if;
		end if;
	end process;
	
	MEMWB_Register_proc: process(clk)
	begin
		if rising_edge(clk) then
			--Insert NOP
			if reset = '1' then
				memwb_nextAddress <= x"00000000";
				memwb_readData <= x"00000000";
				memwb_ALUOutput <= x"00000000";
				memwb_muldivOutput <= x"00000000";
				memwb_rd <= "00000";
				memwb_wbEnabled <= '0';
				memwb_wbMUXSelect <= "00";
				
			else --Update Pipeline regs
				memwb_nextAddress <= exmem_nextAddress;
				memwb_readData <= readdata;
				memwb_ALUOutput <= exmem_ALUOutput;
				memwb_muldivOutput <= exmem_muldivOutput;
				memwb_rd <= exmem_rd;
				memwb_wbEnabled <= exmem_wbEnabled;
				memwb_wbMUXSelect <= exmem_wbMUXSelect;
				
			end if;
		end if;
	end process;
	
	--Instruction Cache external connectivity
	ICacheCurrAddress <= pc;
	
	--MEM stage shared external connectivity
	DataOperation <= exmem_dataOperation;
	ReadNotWrite <= exmem_dataReadNotWrite;
	DataAddress <= exmem_ALUOutput;
	writedata <= exmem_rs2_data;

end architecture;