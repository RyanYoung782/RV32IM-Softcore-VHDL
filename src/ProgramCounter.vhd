library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ProgramCounter is
  port(
    clk : in std_logic;
    reset : in std_logic;
    stall : in std_logic;
    branch_taken : in std_logic;
    branch_addr : in std_logic_vector(31 downto 0);
    
    pc : out std_logic_vector(31 downto 0);
    pc_plus_4 : out std_logic_vector(31 downto 0)
  );
end entity ProgramCounter;

architecture rtl of ProgramCounter is
  signal pc_reg : std_logic_vector(31 downto 0);
  signal next_pc : std_logic_vector(31 downto 0);
  
begin

  --next pc value determination. MUXes the branch_addr and pc_reg with branch_taken as the select signal.
  next_pc <= branch_addr when branch_taken = '1' else
             std_logic_vector(unsigned(pc_reg) + 4);

  --Synchronous: On the rising edge of the clock, reset OR Update PC OR stall
  count_proc: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        pc_reg <= (others => '0');
      elsif stall = '0' then
        pc_reg <= next_pc;
      end if;
      --If stall = '1', then pc_reg does not update and it retains it's value.
    end if;
  end process;

  --Combinational outputs
  pc <= pc_reg;
  pc_plus_4 <= std_logic_vector(unsigned(pc_reg) + 4);

end architecture;