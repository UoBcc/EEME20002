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
           dataOut : out STD_LOGIC_VECTOR (7 downto 0);
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
    -- concurrent calculations
    numWords <= n1(3 downto 0) & n2(3 downto 0) & n3(3 downto 0)
    -- splitting data results into 8 byte chunks for tx
    DRbyte6 <= dataResultsStore(55 downto 48)
    DRbyte5 <= dataResultsStore(47 downto 40)
    DRbyte4 <= dataResultsStore(39 downto 32)
    DRbyte3 <= dataResultsStore(31 downto 24)
    DRbyte2 <= dataResultsStore(23 downto 16)
    DRbyte1 <= dataResultsStore(16 downto 8)
    DRbyte0 <= dataResultsStore(7 downto 0)
    -- splitting and also converting the bcd result to an ascii output
    MIbyte2 <= '0011' & maxIndexStore(11 downto 8) --hundreds
    MIbyte1 <= '0011' & maxIndexStore(7 downto 4) --tens
    MIbyte0 <= '0011' & maxIndexStore(3 downto 0) --units

    -- next state logic
    combi_nextState: process(curState, remaining inputs) --need to complete
    BEGIN
        CASE curState IS
        -- assign default values to all outputs to avoid inferred latches
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
                a <= word;
                done <= '1';
                nextState <= nextWordA;
                ELSE nextState <= INIT;
                END IF;
            
            WHEN nextWordA =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordAN;
                ELSE nextState <= nextWordA;
                END IF;

            WHEN processWordAN =>
                IF unsigned(word)>='00110000' AND unsigned(word)<='00111001' THEN
                n1 <= word;
                done <= '1';
                nextState <= nextWordAN;
                ELSIF resultsStored='1' THEN nextState <= waitNextWord;
                ELSE nextState <= INIT;
                END IF;
            
            WHEN nextWordAN =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordANN;
                ELSE nextState <= nextWordAN;
                END IF;

            WHEN processWordANN =>
                IF unsigned(word)>='00110000' AND unsigned(word)<='00111001' THEN
                n2 <= word;
                done <= '1';
                nextState <= nextWordANN;
                ELSIF resultsStored='1' THEN nextState <= waitNextWord;
                ELSE nextState <= INIT;
                END IF;
            
            WHEN nextWordANN =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordANNN;
                ELSE nextState <= nextWordANN;
                END IF;

            WHEN processWordANNN =>
                IF unsigned(word)>='00110000' AND unsigned(word)<='00111001' THEN
                n3 <= word;
                start <= '1';
                nextState <= startDataProc;
                resultsStored <= '0';
                ELSIF resultsStored='1' THEN nextState <= waitNextWord;
                ELSE nextState <= INIT;
                END IF;
            
            WHEN startDataProc =>
                start <= '1';
                nextState <= waitDataReady;
            
            WHEN waitDataReady =>
                IF dataReady='0' THEN nextState <= waitDataReady;
                ELSE
                start <= '0'
                dataOut <= byte;
                txNow <= '1';
                nextState <= sendData;
                END IF;
            
            WHEN sendData =>
                IF txDone='0' THEN nextState <= sendData;
                ELSIF txDone='1' AND seqDone='1' THEN nextState <= waitNextWord;
                ELSIF txDone='1' AND seqDone='0' THEN
                nextState <= startDataProc;
                maxIndexStore <= maxIndex;
                dataResultsStore <= dataResults;
                --results stored will bring the flow back to wait for l or p in the event an incomplete ANNN command is input
                resultsStored <= '1';
                END IF;

            WHEN waitNextWord =>
                IF reset='0' THEN nextState <= INIT;
                ELSIF valid='1' AND oe='0' AND fe='1' THEN
                    word <= data;
                    nextState <= processWordLP;
                ELSE nextState <= waitNextWord;
                END IF;
            
            WHEN processWordLP =>
                --statement to check l or L
                IF word='01001100' OR '01101100' THEN
                nextState <= listResults;
                -- statement to check for p or p
                ELSIF word='01010000' OR '01110000' THEN
                nextState <= peakResults;
                --statement to check if a or A
                ELSIF word='01100001' OR word='01000001' THEN
                nextState <= nextWordA;
                ELSE nextState <= processWordLP;
            
            WHEN listResults =>


            



            

            

            
            

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