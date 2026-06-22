library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_constants.all;

entity DataCache is
	generic(
		addressWidth: integer := 10 --1024 storage locations
	);
	port(
		clk: in std_logic; --requires clock for synrchronous writes
		useEnabled: in std_logic;
		dataReadNotWrite: in std_logic;
		dataOperation : in data_access_size_t;
		dataAddress: in std_logic_vector(31 downto 0);
		writeData: in std_logic_vector(31 downto 0);
		readdata: out std_logic_vector(31 downto 0)
	);
end DataCache;

architecture rtl of DataCache is

	--Declare and instantiate the data memory. 1024*32 = 4KB
	type memory_t is array (0 to (2**addressWidth)-1) of std_logic_vector(31 downto 0);
	signal memory : memory_t := (others => (others => '0'));
	signal addressPointer : std_logic_vector(addressWidth - 1 downto 0);
	signal alignment : std_logic_vector(1 downto 0);
	signal writtenWord: std_logic_vector(31 downto 0);
begin	
	--Combinational address calculation
	addressPointer <= dataAddress(addressWidth + 1 downto 2);
	alignment <= dataAddress(1 downto 0);
	
	write_proc: process(clk)
	begin
		if rising_edge(clk) then 
			if (useEnabled = '1' and dataReadNotWrite = '0') then 
				memory(to_integer(unsigned(addressPointer))) <= writtenWord;
			end if;
		end if;
	end process;
			
	combinational_proc: process(useEnabled, dataReadNotWrite, dataOperation, dataAddress, memory, addressPointer, alignment, writeData)
		variable word : std_logic_vector(31 downto 0);
	begin	
		--Get data word being utilized
		word := memory(to_integer(unsigned(addressPointer)));
		
		--Initial value of readdata
		readdata <= (others => '0');
		writtenWord <= (others => '0');
		if useEnabled = '1' then
			if dataReadNotWrite = '1' then
				case dataOperation is
					when DATA_BYTE =>
						case alignment is
							when "00" =>
								readdata <= std_logic_vector(resize(signed(word(7 downto 0)), 32));
								
							when "01" =>
								readdata <= std_logic_vector(resize(signed(word(15 downto 8)), 32));
								
							when "10" =>
								readdata <= std_logic_vector(resize(signed(word(23 downto 16)), 32));
								
							when "11" =>
								readdata <= std_logic_vector(resize(signed(word(31 downto 24)), 32));
								
							when others =>
								readdata <= (others => '0');
								
						end case;
						
					when DATA_HALF =>
						case alignment(1) is
							when '0' =>
								readdata <= std_logic_vector(resize(signed(word(15 downto 0)), 32));
								
							when '1' =>
								readdata <= std_logic_vector(resize(signed(word(31 downto 16)), 32));
								
							when others =>
								readdata <= (others => '0');
								
						end case;
						
					when DATA_WORD =>
						--return given word
						readdata <= word;
						
					when DATA_UNSIGNED_BYTE =>
						case alignment is
							when "00" =>
								readdata <= std_logic_vector(resize(unsigned(word(7 downto 0)), 32));
								
							when "01" =>
								readdata <= std_logic_vector(resize(unsigned(word(15 downto 8)), 32));
								
							when "10" =>
								readdata <= std_logic_vector(resize(unsigned(word(23 downto 16)), 32));
								
							when "11" =>
								readdata <= std_logic_vector(resize(unsigned(word(31 downto 24)), 32));
								
							when others =>
								readdata <= (others => '0');
								
						end case;
						
					when DATA_UNSIGNED_HALF =>
						case alignment(1) is
							when '0' =>
								readdata <= std_logic_vector(resize(unsigned(word(15 downto 0)), 32));
								
							when '1' =>
								readdata <= std_logic_vector(resize(unsigned(word(31 downto 16)), 32));
								
							when others =>
								readdata <= (others => '0');
								
						end case;
						
					when others =>  --DATA_DEFAULT
						null;
						
				end case;
				
			else  --Prep write data to be put into memory
				case dataOperation is
					when DATA_BYTE =>
						case alignment is
							when "00" =>
								writtenWord <= word(31 downto 8) & writeData(7 downto 0);
								
							when "01" =>
								writtenWord <= word(31 downto 16) & writeData(7 downto 0) & word(7 downto 0);
								
							when "10" =>
								writtenWord <= word(31 downto 24) & writeData(7 downto 0) & word(15 downto 0);
								
							when "11" =>
								writtenWord <= writeData(7 downto 0) & word(23 downto 0);
								
							when others =>
								writtenWord <= (others => '0');
								
						end case;
						
					when DATA_HALF =>
						case alignment(1) is
							when '0' =>
								writtenWord <= word(31 downto 16) & writeData(15 downto 0);
								
							when '1' =>
								writtenWord <= writeData(15 downto 0) & word(15 downto 0);
								
							when others =>
								writtenWord <= (others => '0');
							
						end case;
					
					when DATA_WORD =>
						writtenWord <= writeData;
						
					when others =>  --DATA_DEFAULT
						writtenWord <= word;
					
				end case;
			end if;
		end if;
	end process;

end architecture;
	
	