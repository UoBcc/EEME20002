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
        maxIndex: in std_logic_vector(11 downto 0);
        dataResults: in std_logic_vector(55 downto 0);
        seqDone: in std_logic;
    );
end cmdProc;

architecture behavoural of cmdProc
    -- constant baudRate : integer := 9600;
    type state_type is (
        INIT, START_DATA_PROCESSING, WAIT_FOR_DATA_READY, SEND_DATA, WAIT_FOR_NEXT_WORD,
        D1, D2, D3, LIST, PEAK -- States need to be workshopped!
        );
    signal curr_state, next_state: state_type;
    signal bcd_reg: std_logic_vector(11 downto 0);
    signal byte_wait: std_logic_vector(7 downto 0);
    -- signal clk: integer := 1;
    -- signal ctrl1, ctrl2: std_logic;

    begin
        state_register: process(clk, reset)
        begin
            if reset = '1' then
                curr_state <= IDLE;
            elsif risingedge(clk) then
                curr_state <= next_state;
            end if;
        end process;
        
        combinational: process(all);
        begin
            next_state <= curr_state;
            rxDone <= '0';
            start <= '1' when curr_state = START_DATA_PROCESSING else '0';
            numWords <= bcd_reg;
            txNow <= '0';
            dataOut <= (others => '0');

            case curr_state is
                when INIT =>
                    if valid = '1' then
                        rxDone <= '1';
                        if (oe = '0' and fe = '0') then
                            if (dataIn = x"41" or dataIn = x"61") then
                                next_state <= D1;
                            elsif (dataIn = x"70" or dataIn = x"50") then
                                next_state <= PEAK;
                            elsif (dataIn = x"4C" or datain = x"6C") then
                                next_state <= LIST;
                            else
                                next_state <= INIT;
                            end if;
                        else
                            next_state <= INIT;
                        end if;
                    end if;

                when D1 =>
                    if valid = '1' then
                        rxDone <= '1';
                        next_state <= (IDLE) when (oe = '1' or fe = '1') else GET_D2;
                end if;

                when GET_D2 =>
                    if valid = '1' then
                        rxDone <= '1';
                        next_state <= (IDLE) when (oe = '1' or fe = '1') else GET_D3;
                    end if;

                when GET_D3 =>
                    if valid = '1' then
                        rxDone <= '1';
                        next_state <= (IDLE) when (oe = '1' or fe = '1') else START_DATA_PROCESSING;
                    end if;

                when START_DATA_PROCESSING =>
                    next_state <= WAIT_FOR_DATA_READY;

                when WAIT_FOR_DATA_READY =>
                    if seqDone = '1' then
                        next_state <= IDLE;
                    end if;

            end case;
        end process;
    end behavoural;
