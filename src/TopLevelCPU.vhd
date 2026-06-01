library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_constants.all;

entity TopLevelCPU is 
	port(
		clk : in std_logic;
		reset : in std_logic
	);
end TopLevelCPU;

architecture layout of TopLevelCPU is
	component InstructionCache is
		port(
			currAddress: in std_logic_vector(31 downto 0);
			currInstruction: out std_logic_vector(31 downto 0)
		);
	end component InstructionCache;
	
	component DataCache is
		port(
			clk: in std_logic;
			useEnabled: in std_logic;
			dataReadNotWrite: in std_logic;
			dataOperation : in data_access_size_t;
			dataAddress: in std_logic_vector(31 downto 0);
			writeData: in std_logic_vector(31 downto 0);
			readdata: out std_logic_vector(31 downto 0)
		);
	end component DataCache;
	
	component CPUDataPath is
		port(
			clk : in std_logic;
			reset : in std_logic;
			ICacheCurrAddress: out std_logic_vector(31 downto 0);
			ICacheCurrInstruction : in std_logic_vector(31 downto 0);
			DCacheUseEnabled: out std_logic;
			DCacheDataReadNotWrite: out std_logic;
			DCacheDataOperation: out data_access_size_t;
			DCacheDataAddress: out std_logic_vector(31 downto 0);
			DCacheWriteData: out std_logic_vector(31 downto 0);
			DCacheReadData: in std_logic_vector(31 downto 0)
		);
	end component CPUDataPath;
	
	--Connective wires
	signal currAddress : std_logic_vector(31 downto 0);
	signal currInstruction : std_logic_vector(31 downto 0);
	signal useEnabled : std_logic;
	signal dataReadNotWrite : std_logic;
	signal dataOperation : data_access_size_t;
	signal dataAddress : std_logic_vector(31 downto 0);
	signal writeData : std_logic_vector(31 downto 0);
	signal readdata : std_logic_vector(31 downto 0);
	
begin
	--Instantiating components
	InstructionCacheInstance : InstructionCache
		port map(
			currAddress => currAddress,
			currInstruction => currInstruction
		);
	
	DataCacheInstance : DataCache
		port map(
			clk => clk,
			useEnabled => useEnabled,
			dataReadNotWrite => dataReadNotWrite,
			dataOperation => dataOperation,
			dataAddress => dataAddress,
			writeData => writeData,
			readdata => readdata
		);
		
	CPUDataPathInstance : CPUDataPath
		port map(
			clk => clk,
			reset => reset,
			ICacheCurrAddress => currAddress,
			ICacheCurrInstruction => currInstruction,
			DCacheUseEnabled => useEnabled,
			DCacheDataReadNotWrite => dataReadNotWrite,
			DCacheDataOperation => dataOperation,
			DCacheDataAddress => dataAddress,
			DCacheWriteData => writeData,
			DCacheReadData => readdata
		);

end architecture;