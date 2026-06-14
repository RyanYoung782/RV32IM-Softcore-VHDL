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
			ICacheCurrAddress : out std_logic_vector(31 downto 0);
			ICacheCurrInstruction : in std_logic_vector(31 downto 0); 
			DCacheUseEnabled : out std_logic;
			MMIOUseEnabled : out std_logic;
			DataOperation : out data_access_size_t;
			ReadNotWrite : out std_logic;
			DataAddress : out std_logic_vector(31 downto 0);
			WriteData : out std_logic_vector(31 downto 0);
			ReadData : in std_logic_vector(31 downto 0)
		);
	end component CPUDataPath;
	
	component MMIOController is
		port (
			clk : in std_logic;
			rst : in std_logic;
			addr : in std_logic_vector(31 downto 0);
			wr_en : in std_logic;
			wr_data : in std_logic_vector(31 downto 0);
			rd_data : out std_logic_vector(31 downto 0);
			sw_in : in std_logic_vector(15 downto 0);
			btn_in : in std_logic_vector(4  downto 0);
			led_out : out std_logic_vector(15 downto 0);
			seg_out : out std_logic_vector(63 downto 0)
		);
	end component MMIOController;
	
	component SevenSegController is
		generic (
			CLK_HZ  : integer := 100000;
			SCAN_HZ : integer := 1000
		);
		port(
			clk : in std_logic;
			rst : in std_logic;
			binaryInput : in std_logic_vector(63 downto 0);
			segmentOut: out std_logic_vector(7 downto 0);
			anode : out std_logic_vector(7 downto 0)
		);
	end component SevenSegController;
		
	--Connective wires
	signal currAddress : std_logic_vector(31 downto 0);
	signal currInstruction : std_logic_vector(31 downto 0);
	signal DCacheUseEnabled : std_logic;
	signal MMIOUseEnabled : std_logic;
	signal readNotWrite : std_logic;
	signal dataOperation : data_access_size_t;
	signal dataAddress : std_logic_vector(31 downto 0);
	signal writeData : std_logic_vector(31 downto 0);
	signal readdata : std_logic_vector(31 downto 0);
	signal DCachereaddata : std_logic_vector(31 downto 0);
	signal MMIOreaddata : std_logic_vector(31 downto 0);
	
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
			useEnabled => DCacheUseEnabled,
			dataReadNotWrite => dataReadNotWrite,
			dataOperation => dataOperation,
			dataAddress => dataAddress,
			writeData => writeData,
			readdata => DCachereaddata
		);
		
	CPUDataPathInstance : CPUDataPath
		port map(
			clk => clk,
			reset => rest,
			ICacheCurrAddress => currAddress,
			ICacheCurrInstruction => currInstruction,
			DCacheUseEnabled => DCacheUseEnabled,
			MMIOUseEnabled => MMIOUseEnabled,
			DataOperation => dataOperation,
			ReadNotWrite => readNotWrite,
			DataAddress => dataAddress,
			WriteData => writeData,
			ReadData => readdata
		);
		
	--FILL IN THESE
	MMIOControllerInstance : MMIOController
		port map(
		
		);
	
	SevenSegControllerInstance : SevenSegController
		generic map(
		
		);
		port map(
		
		);
		
	--NEED TO MUX MMIOController and DCache readdata outputs to select which one was used in prev transaction...
	--Select signal will be dmem_enabled & mmio_enabled signals stitched tgt

end architecture;