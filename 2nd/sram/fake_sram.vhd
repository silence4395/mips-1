library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- fake implementation of SRAM for testing
-- it needs more configuration to match with actual SRAM

entity fake_sram is

  port (
    -- data and parity
    ZD:  inout std_logic_vector(31 downto 0);
    ZDP: inout std_logic_vector(3 downto 0);

    -- address
    ZA     : in std_logic_vector(19 downto 0);

    -- X write enable
    XWA    : in std_logic;

    -- use for clock
    ZCLKMA : in std_logic_vector(1 downto 0);

    -- ignored
    XE1    : in std_logic; -- 0
    E2A    : in std_logic; -- 1
    XE3    : in std_logic; -- 0

    XZBE   : in std_logic_vector(3 downto 0); -- 0000

    XGA    : in std_logic; -- 0

    XZCKE  : in std_logic; -- 0
    ADVA   : in std_logic; -- 0
    XFT    : in std_logic; -- 1
    XLBO   : in std_logic; -- 1
    ZZA    : in std_logic  -- 0
);

end fake_sram;

architecture behave of fake_sram is

  constant MEM_SIZE : integer := 1024;

  -- address max for 20bits: 1048576
  -- blockram is capable
  -- 1024 for test
  type ram_type is array (MEM_SIZE downto 0) of std_logic_vector(31 downto 0);
  signal mem : ram_type;

  signal sram_data : std_logic_vector(31 downto 0);

  signal addr1 : std_logic_vector(19 downto 0);

  signal clk : STD_LOGIC;
  signal previous_XWA : STD_LOGIC;
  signal internal_address : std_logic_vector(19 downto 0);

  signal write_data : std_logic_vector(31 downto 0);

begin  -- behave

  ZD  <= sram_data when previous_XWA='1' else (others => 'Z');
  ZDP <= (others => 'Z'); -- not available

  clk <= ZCLKMA(0);

  assert XE1   = '0' report "Fake SRAM: XE1";
  assert E2A   = '1' report "Fake SRAM: E2A";
  assert XE3   = '0' report "Fake SRAM: XE3";
  assert XGA   = '0' report "Fake SRAM: XGA";
  assert XZCKE = '0' report "Fake SRAM: XZCKE";
  assert ADVA  = '0' report "Fake SRAM: ADVA";
  assert XFT   = '0' report "Fake SRAM: XFT";
  assert XLBO  = '1' report "Fake SRAM: XLBO";
  assert ZZA   = '0' report "Fake SRAM: ZZA";

  assert XZBE  = "0000" report "Fake SRAM: XZBE";

  process (clk)
  begin
    if rising_edge(clk) then
      previous_XWA <= XWA;
      addr1 <= internal_address;
    end if;
  end process;

  internal_address <= "0000000000" & ZA(9 downto 0);

  sram_mock: process (clk, ZD, ZA, XWA)
  begin  -- process sram_mock
    if falling_edge(clk) then
      write_data <= ZD;
    end if;
    if rising_edge(clk) then
      if XWA = '0' then
        -- ZA is always connected. problem is in when it is writing
        assert ZA <= MEM_SIZE report "Writing.. ZA is greater than 1024.";
      end if;

      sram_data <= mem(conv_integer(internal_address));

      if previous_XWA = '0' then
        mem(conv_integer(addr1)) <= write_data;
      end if;
    end if;
  end process sram_mock;

end behave;
