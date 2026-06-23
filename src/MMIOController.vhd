library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MMIOController is
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- From MEM stage
        addr : in std_logic_vector(31 downto 0);
        wr_en : in std_logic;
        wr_data : in std_logic_vector(31 downto 0);
        rd_data : out std_logic_vector(31 downto 0);

        -- Synchronized board inputs
        sw_in : in std_logic_vector(15 downto 0);
        btn_in : in std_logic_vector(4  downto 0);

        -- Board outputs
        led_out : out std_logic_vector(15 downto 0);
        seg_out : out std_logic_vector(63 downto 0)
    );
end entity;

architecture behavior of MMIOController is

    constant ADDR_SW : std_logic_vector(7 downto 0) := x"00";
    constant ADDR_BTN : std_logic_vector(7 downto 0) := x"04";
    constant ADDR_LED : std_logic_vector(7 downto 0) := x"08";
    constant ADDR_SEG_LO : std_logic_vector(7 downto 0) := x"0C";
	constant ADDR_SEG_HI : std_logic_vector(7 downto 0) := x"10";

    signal led_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal seg_lo_reg : std_logic_vector(31 downto 0) := (others => '1');
	signal seg_hi_reg : std_logic_vector(31 downto 0) := (others => '1');

begin
	
	--Interconnect between controller and LED / 7-Seg Controllers
    led_out <= led_reg;
    seg_out <= seg_hi_reg & seg_lo_reg;

	--Synchronous register write
    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                led_reg <= (others => '0');
                seg_hi_reg <= (others => '1');
                seg_lo_reg <= (others => '1');
            elsif wr_en = '1' then
                case addr(7 downto 0) is
                    when ADDR_LED => 
						led_reg <= wr_data(15 downto 0);
						
                    when ADDR_SEG_LO => 
						seg_lo_reg <= wr_data;
						
					when ADDR_SEG_HI =>
						seg_hi_reg <= wr_data;
						
                    when others => 
						null;
						
                end case;
            end if;
        end if;
    end process;

	--Combinational register read
    read_proc : process(addr, sw_in, btn_in, led_reg)
    begin
        case addr(7 downto 0) is
            when ADDR_SW => 
				rd_data <= x"0000"   & sw_in;
				
            when ADDR_BTN => 
				rd_data <= x"000000" & "000" & btn_in;
			
            when ADDR_LED => 
				rd_data <= x"0000"   & led_reg;
			
            when others => 
				rd_data <= (others => '0');
			
        end case;
    end process;

end architecture;