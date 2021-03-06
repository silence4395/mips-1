library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity rs232c_buffer is
  
  generic (wtime : std_logic_vector(15 downto 0) := x"008F");

  port (
    clk       : in std_logic;
    reset     : in std_logic;
    push      : in std_logic;           -- 1 to push data
    push_data : in std_logic_vector(7 downto 0);
    tx        : out std_logic);

end rs232c_buffer;

architecture behave of rs232c_buffer is

  component u232c
    generic (wtime : std_logic_vector(15 downto 0) := wtime;
             len : integer range 1 to 8  := 1);
    port (
      clk  : in  STD_LOGIC;
      data : in  STD_LOGIC_VECTOR (len * 8-1 downto 0);
      go   : in  STD_LOGIC;
      busy : out STD_LOGIC;
      tx   : out STD_LOGIC);
  end component;

  -- Current config
  -- Common clock, built-in FIFO
  -- Width: 8, Depth: 1024 (it should be determined from max length of ppm file)
  -- others are default
  COMPONENT fifo
    PORT (
      clk : IN STD_LOGIC;
      rst : IN STD_LOGIC;
      din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      wr_en : IN STD_LOGIC;
      rd_en : IN STD_LOGIC;
      dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      full : OUT STD_LOGIC;
      empty : OUT STD_LOGIC
      );
  END COMPONENT;

  signal go, busy : std_logic;

  signal full, empty : std_logic := '0';      -- full is not used
  signal rd_en : std_logic := '0';
  signal send_data : std_logic_vector(7 downto 0);

begin  -- behave

  send_data_queue : fifo
    PORT MAP (
      clk => clk,
      rst => reset,
      din => push_data,
      wr_en => push,
      rd_en => rd_en,
      dout => send_data,
      full => full,
      empty => empty
      );

  sender : u232c port map (
    clk  => clk,
    data => send_data,
    go   => go,
    busy => busy,
    tx   => tx);

  pop: process (clk, reset)
  begin  -- process pop
    if reset = '1' then
      rd_en <= '0';
      go <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if busy = '0' then
        if rd_en = '0' and go = '0' then
          rd_en <= not empty ;
        else
          rd_en <= '0';
          go <= '1';
        end if;
      else
        rd_en <= '0';
        go <= '0';
      end if;
    end if;
  end process pop;
  
end behave;
