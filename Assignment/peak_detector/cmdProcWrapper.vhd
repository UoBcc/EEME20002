library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common_pack.all;

entity cmdProc is
port (
    clk:          in std_logic;
    reset:        in std_logic;
    rxnow:        in std_logic;
    rxData:       in std_logic_vector (7 downto 0);
    txData:       out std_logic_vector (7 downto 0);
    rxdone:       out std_logic;
    ovErr:        in std_logic;
    framErr:      in std_logic;
    txnow:        out std_logic;
    txdone:       in std_logic;
    start:        out std_logic;
    numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
    dataReady:    in std_logic;
    byte:         in std_logic_vector(7 downto 0);
    maxIndex:     in BCD_ARRAY_TYPE(2 downto 0);
    dataResults:  in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone:      in std_logic
    );
end cmdProc;

architecture Behavioral of cmdProc is

    -- This declaration perfectly matches the component you synthesized
    component cmdProc_synthesised is
        Port ( valid : in STD_LOGIC;
               oe : in STD_LOGIC;
               fe : in STD_LOGIC;
               data : in STD_LOGIC_VECTOR (7 downto 0);
               done : out STD_LOGIC;
               txDone : in STD_LOGIC;
               dataOut : out STD_LOGIC_VECTOR (7 downto 0);
               txNow : out STD_LOGIC;
               dataReady : in STD_LOGIC;
               byte : in STD_LOGIC_VECTOR (7 downto 0);
               maxIndex : in STD_LOGIC_VECTOR (11 downto 0);
               dataResults : in STD_LOGIC_VECTOR (55 downto 0);
               seqDone : in STD_LOGIC;
               start : out  STD_LOGIC;
               numWords : out STD_LOGIC_VECTOR (11 downto 0);
               clk : in STD_LOGIC;
               reset : in STD_LOGIC);
    end component;

    -- Intermediate signals to translate the complex arrays to flat vectors
    signal maxIndex_flat    : STD_LOGIC_VECTOR(11 downto 0);
    signal numWords_flat    : STD_LOGIC_VECTOR(11 downto 0);
    signal dataResults_flat : STD_LOGIC_VECTOR(55 downto 0);

begin

    -- Translate the incoming arrays into flat vectors for your component
    maxIndex_flat(11 downto 8) <= maxIndex(2);
    maxIndex_flat(7 downto 4)  <= maxIndex(1);
    maxIndex_flat(3 downto 0)  <= maxIndex(0);

    dataResults_flat(55 downto 48) <= dataResults(0);
    dataResults_flat(47 downto 40) <= dataResults(1);
    dataResults_flat(39 downto 32) <= dataResults(2);
    dataResults_flat(31 downto 24) <= dataResults(3);
    dataResults_flat(23 downto 16) <= dataResults(4);
    dataResults_flat(15 downto 8)  <= dataResults(5);
    dataResults_flat(7 downto 0)   <= dataResults(6);

    -- Translate your outgoing flat vector into the array the testbench expects
    numWords_bcd(2) <= numWords_flat(11 downto 8);
    numWords_bcd(1) <= numWords_flat(7 downto 4);
    numWords_bcd(0) <= numWords_flat(3 downto 0);

    -- Instantiate your synthesized black-box component
    cmdProc_struct1: cmdProc_synthesised
    port map (
          -- Inner Port => Outer Wrapper Port/Signal
          clk         => clk,
          reset       => reset,
          valid       => rxnow,       -- Maps inner 'valid' to outer 'rxnow'
          data        => rxData,      -- Maps inner 'data' to outer 'rxData'
          dataOut     => txData,      -- Maps inner 'dataOut' to outer 'txData'
          done        => rxdone,      -- Maps inner 'done' to outer 'rxdone'
          oe          => ovErr,       -- Maps inner 'oe' to outer 'ovErr'
          fe          => framErr,     -- Maps inner 'fe' to outer 'framErr'
          txNow       => txnow,
          txDone      => txdone,
          start       => start,
          dataReady   => dataReady,
          byte        => byte,
          seqDone     => seqDone,
          maxIndex    => maxIndex_flat,
          numWords    => numWords_flat,
          dataResults => dataResults_flat
    );

end Behavioral;