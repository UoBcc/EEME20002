----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.02.2019 21:00:29
-- Design Name: 
-- Module Name: cmdProc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common_pack.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cmdProc is
port (
    clk:		in std_logic;
    reset:        in std_logic;
    rxnow:        in std_logic;
    rxData:            in std_logic_vector (7 downto 0);
    txData:            out std_logic_vector (7 downto 0);
    rxdone:        out std_logic;
    ovErr:        in std_logic;
    framErr:    in std_logic;
    txnow:        out std_logic;
    txdone:        in std_logic;
    start: out std_logic;
    numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
    dataReady: in std_logic;
    byte: in std_logic_vector(7 downto 0);
    maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
    dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone: in std_logic
    );
end cmdProc;

architecture Behavioral of cmdProc is

    component cmdProc_synthesised is
     port (
      clk : in STD_LOGIC;
      dataReady : in STD_LOGIC;
      framErr : in STD_LOGIC;
      ovErr : in STD_LOGIC;
      reset : in STD_LOGIC;
      rxdone : out STD_LOGIC;
      rxnow : in STD_LOGIC;
      seqDone : in STD_LOGIC;
      start : out STD_LOGIC;
      txdone : in STD_LOGIC;
      txnow : out STD_LOGIC;
      byte : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[0]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[1]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[2]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[3]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[4]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[5]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \dataResults[6]\ : in STD_LOGIC_VECTOR ( 7 downto 0 );
      \maxIndex[0]\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
      \maxIndex[1]\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
      \maxIndex[2]\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
      \numWords_bcd[0]\ : out STD_LOGIC_VECTOR ( 3 downto 0 );
      \numWords_bcd[1]\ : out STD_LOGIC_VECTOR ( 3 downto 0 );
      \numWords_bcd[2]\ : out STD_LOGIC_VECTOR ( 3 downto 0 );
      rxData : in STD_LOGIC_VECTOR ( 7 downto 0 );
      txData : out STD_LOGIC_VECTOR ( 7 downto 0 )
     ); 
    end component;

--for cmdProc_struct1:cmdProc_struct use entity work.cmdProc(STRUCTURE);

begin
    cmdProc_struct1: cmdProc_synthesised
    port map (
          clk => clk,
          reset => reset,
          rxNow => dataReady,
          rxData => data,
          txData => dataOut,
          rxDone => done,
          ovErr => oe,
          framErr => fe,
          txNow => txNow,
          txDone => txDone,
          start => start,
          \numWords_bcd[0]\ => MIbyte0,
          \numWords_bcd[1]\ => MIbyte1,
          \numWords_bcd[2]\ => MIbyte2,
          dataReady => dataReady,
          byte => byte,
          \maxIndex[0]\ => maxIndexStore(11 downto 8),
          \maxIndex[1]\ => maxIndexStore(7 downto 4),
          \maxIndex[2]\ => maxIndexStore(3 downto 0),
          seqDone => seqDone,
          \dataResults[0]\ => dataResultsStore(55 downto 48),
          \dataResults[1]\ => dataResultsStore(47 downto 40),
          \dataResults[2]\ => dataResultsStore(39 downto 32),
          \dataResults[3]\ => dataResultsStore(31 downto 24),
          \dataResults[4]\ => dataResultsStore(23 downto 16),
          \dataResults[5]\ => dataResultsStore(15 downto 8),
          \dataResults[6]\ => dataResultsStore(7 downto 0)
        );

end Behavioral;