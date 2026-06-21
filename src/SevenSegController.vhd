library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SevenSegController is
	--For variable CPU speeds. Necessary for when I update my CPU
	--And it will not necessarily run at the same Hz as a prev iteration...
	generic (
        CLK_HZ  : integer := 100000;
        SCAN_HZ : integer := 1000
    );
	port(
		clk : in std_logic;
		rst : in std_logic;
		binaryInput : in std_logic_vector(63 downto 0);
		segmentOut: out std_logic_vector(7 downto 0);
		anode : out std_logic_vector(7 downto 0)  --Note: Active low for the Nexys A7 100T
	);
end entity;

architecture build of SevenSegController is

	constant COUNT_MAX : integer := CLK_HZ / SCAN_HZ / 8;
    signal counter : integer range 0 to COUNT_MAX - 1 := 0;
    signal digit_idx : integer range 0 to 7 := 0;
    signal active_byte : std_logic_vector(7 downto 0);

begin 

    -- Extract current digit's 8-bit field from packed register
    active_byte <= binaryInput(digit_idx * 8 + 7 downto digit_idx * 8);

    --Preps for the write to the 7-seg register
    segmentOut <= active_byte;

    --Updates a single digit every SCAN_HZ / 8 Clock cycles :)
    refresh_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter   <= 0;
                digit_idx <= 0;
            elsif counter = COUNT_MAX - 1 then
                counter <= 0;
                if digit_idx = 7 then
                    digit_idx <= 0;
                else
                    digit_idx <= digit_idx + 1;
                end if;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- Digit select (active low)
    anode_proc : process(digit_idx)
    begin
		--Active Low anodes
        anode <= (others => '1');
        anode(digit_idx) <= '0';
    end process;

end architecture;