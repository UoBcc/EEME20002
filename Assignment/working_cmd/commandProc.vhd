library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity cmdProc is 
    port (
        clk: in std_logic;
        reset: in std_logic;

        rxDone: out std_logic;
        dataIn: in std_logic_vector(7 downto 0);
        valid: in std_logic; -- dataReady in Rx port description
        oe: in std_logic;
        fe: in std_logic;

        dataOut: out std_logic_vector(7 downto 0);
        txNow: out std_logic;
        txDone: in std_logic;

        start: out std_logic;
        numWords: out std_logic_vector(11 downto 0);
        dataReady: in std_logic;
        byte: in std_logic_vector(7 downto 0);
        maxIndex: in std_logic_vector(11 downto 0)
        dataResults: in std_logic_vector(55 downto 0)
        seqDone: in std_logic;
    );
end cmdProc;

architecture behavoural of cmdProc
    constant baudRate : integer := 9600;
    type state_type is (
        INIT, LOAD_WORD, PROCESS_WORD, START_DATA_PROCESSING, WAIT_FOR_DATA_READY, SEND_DATA, WAIT_FOR_NEXT_WORD
        );
    signal curr_state, next_state: state_type;

    begin
    end behavoural;
