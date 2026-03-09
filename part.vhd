library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;

entity cmdProc is
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    rxnow         : in  std_logic;
    rxData        : in  std_logic_vector (7 downto 0);
    txData        : out std_logic_vector (7 downto 0);
    rxdone        : out std_logic;
    ovErr         : in  std_logic;
    framErr       : in  std_logic;
    txnow         : out std_logic;
    txdone        : in  std_logic;
    start         : out std_logic;
    numWords_bcd  : out BCD_ARRAY_TYPE(2 downto 0);
    dataReady     : in  std_logic;
    byte          : in  std_logic_vector(7 downto 0);
    maxIndex      : in  BCD_ARRAY_TYPE(2 downto 0);
    dataResults   : in  CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone       : in  std_logic
  );
end entity;
----我的部分，从数据加载完成到指令完成
architecture rtl of instruction_parser is
  type state_type is (load_data; process_word; send_list;)
    signal state : state_type;
    constant   : std_logic_vector(7 downto 0) := x"01";
    constant CMD_DISPLAY_PEAK : std_logic_vector(7 downto 0) := x"02";
