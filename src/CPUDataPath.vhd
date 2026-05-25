library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_constants.all;

entity CPUDataPath is
	port(
		--Input Clock Signal
		clk: in std_logic;
		
		--Instruction Cache Interface
		ICacheCurrAddress: out std_logic_vector(31 downto 0);
		ICacheCurrInstruction : in std_logic_vector(31 downto 0);
		
		--Data Cache Interface
		DCacheUseEnabled: out std_logic;
		DCacheDataReadNotWrite: out std_logic;
		DCacheDataOperation: out data_access_size_t;
		DCacheDataAddress: out std_logic_vector(31 downto 0);
		DCacheWriteData: out std_logic_vector(31 downto 0);
		DCacheReadData: in std_logic_vector(31 downto 0);
	);
end CPUDataPath;

architecture rtl of CPUDataPath is
	--Internal Signals
	--IF Internal Signals
	signal currentAddress: std_logic_vector(31 downto 0);
	
	--ID Internal Signals
	signal rs1 : std_logic_vector(4 downto 0);
	signal rs2 : std_logic_vector(4 downto 0);
	
	--EX Internal Signals
	signal operand1: std_logic_vector(31 downto 0);
	signal operand2: std_logic_vector(31 downto 0);
	
	--MEM Internal Signals
	
	--WB Internal Signals
	
	--IFID Pipeline Register
	signal ifid_nextAddress : std_logic_vector(31 downto 0);
	signal ifid_currInstruction: std_logic_vector(31 downto 0);
	
	--IDEX Pipeline Register
	signal idex_branchCondition : std_logic_vector(2 downto 0);
	signal idex_branchEnabled : std_logic;
	signal idex_nextAddress : std_logic_vector(31 downto 0);
	signal idex_rs1 : std_logic_vector(31 downto 0);
	signal idex_rs2 : std_logic_vector(31 downto 0);
	signal alu_op : alu_op_t;
	signal muldiv_op : muldiv_op_t;
	signal idex_rd : std_logic_vector(4 downto 0);
	signal idex_wbEnabled : std_logic;
	signal idex_immVal : std_logic_vector(31 downto 0);
	signal idex_dataEnabled: std_logic;
	signal idex_dataReadNotWrite: std_logic;
	signal idex_dataOperation: data_access_size_t;
	signal idex_wbMUXSelect : std_logic_vector(1 downto 0);
	
	--EXMEM Pipeline Register
	signal exmem_nextAddress : std_logic_vector(31 downto 0);
	signal exmem_branchAddress : std_logic_vector(31 downto 0);
	signal exmem_branchTaken : std_logic;
	signal exmem_ALUOutput : std_logic_vector(31 downto 0);
	signal exmem_muldivOutput : std_logic_vector(31 downto 0);
	signal exmem_muldivDone : std_logic;
	signal exmem_rd : std_logic_vector(4 downto 0);
	signal exmem_wbEnabled : std_logic;
	
	--MEMWB Pipeline Register
	signal memwb_nextAddress : std_logic_vector(31 downto 0);
	signal memwb_readData : std_logic_vector(31 downto 0);
	signal memwb_ALUOutput : std_logic_vector(31 downto 0);
	signal memwb_muldivOutput : std_logic_vector(31 downto 0);
	signal memwb_rd : std_logic_vector(4 downto 0);
	signal memwb_wbEnabled : std_logic;
	
	--Component Declarations
	component BranchingUnit is
		port(
		
		);
	end BranchingUnit;
	
	component ForwardingUnit is
		port(
		
		);
	end ForwardingUnit;
	
	component HazardDetectionUnit is
		port(
		
		);
	end HazardDetectionUnit;
	
	component InstructionDecoder is 
		port(
		
		);
	end InstructionDecoder;
	
	component IntegerALU is
		port(
		
		);
	end IntegerALU;
	
	component MuldivUnit is 
		port(
		
		);
	end MuldivUnit;
	
	component ProgramCounter is
		port(
		
		);
	end ProgramCounter;
	
	component RegisterFile is
		port(
		
		);
	end RegisterFile;
	
begin
	--Component Instantiations
	BranchingUnitInstance : BranchingUnit
		port map();
	
	ForwardingUnitInstance : ForwardingUnit
		port map();
		
	HazardDetectionUnitInstance : HazardDetectionUnit
		port map();
		
	

end architecture;