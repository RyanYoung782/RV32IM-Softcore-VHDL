library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity CPUDataPath_tb is
end entity;

architecture tb of CPUDataPath_tb is
	--DUT Signals
	signal clk : std_logic;
	signal reset : std_logic;
	signal ICacheCurrAddress : std_logic_vector(31 downto 0);
	signal ICacheCurrInstruction : std_logic_vector(31 downto 0);
	signal DCacheUseEnabled : std_logic;
	signal MMIOUseEnabled : std_logic;
	signal DataOperation : data_access_size_t;
	signal ReadNotWrite : std_logic;
	signal DataAddress : std_logic_vector(31 downto 0);
	signal writedata : std_logic_vector(31 downto 0);
	signal readdata : std_logic_vector(31 downto 0);
	
	--DUT Component
	component CPUDataPath is
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
	end component CPUDataPath;

begin

end architecture;