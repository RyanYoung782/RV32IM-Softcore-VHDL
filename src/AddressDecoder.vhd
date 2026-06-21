library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AddressDecoder is
	port(
		dataAddress : in std_logic_vector(31 downto 0);
		dataEnabled : in std_logic;
		dmem_sel : out std_logic;
		mmio_sel : out std_logic
	);
end entity;

architecture behavior of AddressDecoder is

	--Only concerned with the top 4 bits of the address!
    signal region : std_logic_vector(3 downto 0);

begin

    region <= dataAddress(31 downto 28);

    selectSource_proc : process(dataAddress, dataEnabled, region)
    begin
        --Defaults
        dmem_sel <= '0';
        mmio_sel <= '0';

        if dataEnabled = '1' then
            case region is
                when x"1" =>
                    dmem_sel <= '1';

                when x"2" =>
                    mmio_sel <= '1';

                when others =>
                    null;
					
            end case;
        end if;
    end process;

end architecture;