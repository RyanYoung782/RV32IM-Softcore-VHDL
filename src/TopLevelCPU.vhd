library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_constants.all;

entity TopLevelCPU is 
	port(
		clk : in std_logic;
		reset : in std_logic;
		async_switch_inputs : in std_logic_vector(15 downto 0);
		async_button_inputs : in std_logic_vector(4 downto 0);
		led_output : out std_logic_vector(15 downto 0);
		cathode_output : out std_logic_vector(7 downto 0);
		anode_output : out std_logic_vector(7 downto 0)
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
	
	component FlipFlipSynchronizer is
		generic (
			STAGES : integer := 2;
			LATCHWIDTH : integer := 16  --Size of the FF registers
		);
		port (
			clk   : in  std_logic;
			async : in  std_logic_vector;
			sync  : out std_logic_vector
		);
	end component FlipFlipSynchronizer;
		
	--Connective wires
	
	--MEM interface wires
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
	
	--MMIO hardware interface wires
	--Switches
	signal sync_switch_inputs : std_logic_vector(15 downto 0);
	--Buttons
	signal sync_button_inputs : std_logic_vector(4 downto 0);
	--LEDs
	signal led_out : std_logic_vector(15 downto 0);
	--7-Segment Displays
	signal segmentBinary : std_logic_vector(63 downto 0);
	
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
			dataReadNotWrite => readNotWrite,
			dataOperation => dataOperation,
			dataAddress => dataAddress,
			writeData => writeData,
			readdata => DCachereaddata
		);
		
	CPUDataPathInstance : CPUDataPath
		port map(
			clk => clk,
			reset => reset,
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
		
	MMIOControllerInstance : MMIOController
		port map(
			clk => clk,
			rst => reset,
			addr => currAddress, 
			wr_en => MMIOUseEnabled,
			wr_data => writeData,
			rd_data => MMIOreaddata,
			sw_in => sync_switch_inputs,
			btn_in => sync_button_inputs,
			led_out => led_output,
			seg_out => segmentBinary
		);
	
	SevenSegControllerInstance : SevenSegController
		generic map(
				CLK_HZ => 100000,
				SCAN_HZ => 1000
		)
		port map(
			clk => clk,
			rst => reset,
			binaryInput => segmentBinary,
			segmentOut => cathode_output,
			anode => anode_output
		);
	
	--Synchronizer for switches
	SwitchFlipFlipSynchronizerInstance : FlipFlipSynchronizer
		generic map(
			STAGES => 2,
			LATCHWIDTH => 16
		)
		port map(
			clk => clk,
			async => async_switch_inputs,
			sync => sync_switch_inputs
		);
	
	--Synchronizer for buttons	
	ButtonFlipFlipSynchronizerInstance : FlipFlipSynchronizer
		generic map(
			STAGES => 2,
			LATCHWIDTH => 5
		)
		port map(
			clk => clk,
			async => async_button_inputs,
			sync => sync_button_inputs
		);
		
		
	--MEM stage readdata MUX
	--Selects between MMIO and DCache readdata to return correct data on the specific operation
	--Completely combinational so the readdata returns instantly where necessary.
	with MMIOUseEnabled & DCacheUseEnabled select readdata <=
		MMIOreaddata when "10",
		DCachereaddata when "01",
		(others => '0') when others;

end architecture;