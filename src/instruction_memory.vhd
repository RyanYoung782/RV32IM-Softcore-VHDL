library ieee;
use ieee.std_logic_1164.all;

package instruction_memory is

	type rom_t is array (0 to 511) of std_logic_vector(31 downto 0);

    constant PROGRAM : rom_t := (
        0 => "00100000000000000000000010110111",
        1 => "00000000000000001010000110000011",
        2 => "00000000001100001010010000100011",
        3 => "11111111100111111111000001101111",
        others => "00000000000000000000000000000000" -- NOP
    );

end package;