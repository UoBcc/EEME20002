library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

entity cmdProc is
    Port ( valid : in STD_LOGIC;
           oe : in STD_LOGIC;
           fe : in STD_LOGIC;
           data : in STD_LOGIC_VECTOR (7 downto 0);
           done : out STD_LOGIC;

           txDone : in STD_LOGIC;
           data : out STD_LOGIC_VECTOR (7 downto 0);
           txNow : out STD_LOGIC:

           dataReady : in STD_LOGIC;
           byte : in STD_LOGIC_VECTOR (7 downto 0);
           maxIndex : in STD_LOGIC_VECTOR (11 downto 0);
           dataResults : in STD_LOGIC_VECTOR (55 downto 0);
           seqDone : in STD_LOGIC;
           start : out  STD_LOGIC;
           numWords : out STD_LOGIC_VECTOR (11 downto 0);
 
           clk : in STD_LOGIC;
           reset : STD_LOGIC;
end cmdProc;

ARCHITECTURE FSM of cmdProc is
    TYPE state_type is (INIT, loadWord, );
    SIGNAL curState, nextState: STATE_TYPE;
BEGIN
    -- Next State Logic
    combi_nextState: process(curState, x)
    BEGIN
        CASE curState IS
        --assign default values to all outputs to avoid inferred latches --
            nextState <= curState; 
            done <= '0';
            data <= '0';
            txNow <= '0';
            start <= '0';
            numWords <= '0'

            WHEN INIT =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordA;
                ELSE nextState <= init;
                END IF;

            WHEN processWordA =>
                IF word='01100001' OR word='01000001' THEN 
                done <= '1';
                nextState <= processWordAN
                ELSE nextState <= INIT;
                END IF;
            
            WHEN nextWordA =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordAN;
                ELSE nextState <= init;
                END IF;

            WHEN processWordAN =>
                IF word='01100001' OR word='01000001' THEN 
                done <= '1';
                nextState <= processWordAN
                ELSE nextState <= INIT;
                END IF;
            
            WHEN nextWordAN =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordAN;
                ELSE nextState <= init;
                END IF;
            
            
            

            WHEN THIRD =>
                IF x='0' THEN nextState <= INIT;
                ELSE nextState <= FIRST;
                END IF;
        END CASE;
    END PROCESS;

    -- Output Logic
    combi_out: PROCESS(curState, x)
    BEGIN
        y <= '0';
        IF curState = THIRD AND x='0' THEN
            y <= '1';
        END IF;
    END PROCESS;

    -- State Register
    seq_state: PROCESS (clk, reset)
    BEGIN
        IF reset = '0' THEN
            curState <= INIT;
        ELSIF clk'event AND clk='1' THEN
            curState <= nextState;
        END IF;
    END PROCESS;
END arch_mealy;