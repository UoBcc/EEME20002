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
           txNow : out STD_LOGIC;

           dataReady : in STD_LOGIC;
           byte : in STD_LOGIC_VECTOR (7 downto 0);
           maxIndex : in STD_LOGIC_VECTOR (11 downto 0);
           dataResults : in STD_LOGIC_VECTOR (55 downto 0);
           seqDone : in STD_LOGIC;
           start : out  STD_LOGIC;
           numWords : out STD_LOGIC_VECTOR (11 downto 0);
 
           clk : in STD_LOGIC;
           reset : in STD_LOGIC;
end cmdProc;

ARCHITECTURE FSM of cmdProc is
    TYPE state_type is (INIT, processWordA, processWordAN, processWordANN, processWordANNN, startDataProc, waitDataReady, sendData, waitNextWordLP, processWordLP, peakResults, txWaitPeak, listResults, txWaitList);

    SIGNAL curState: STATE_TYPE := INIT; --converted to curState only single FSM to avoid inferred latches from curState and nextState FSM design from TB1 labs

    SIGNAL word : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL a : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n1 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n3 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); --init all ascii signals

    SIGNAL maxIndexStore : STD_LOGIC_VECTOR(55 downto 0) := (others => '0');
    SIGNAL dataResultsStore : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); --init data stores

    SIGNAL resultsStored : STD_LOGIC := '0';
    SIGNAL txCount : unsigned(2 downto 0) := "000"; --init "counters" (resultsStored counts as a counter right?)

    SIGNAL MIbyte0, MIbyte1, MIbyte2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL LRbyte0, LRbyte1, LRbyte2, LRbyte3, LRbyte4, LRbyte5, LRbyte6 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    
    

BEGIN
    -- concurrent calculations
    numWords <= n1(3 downto 0) & n2(3 downto 0) & n3(3 downto 0);
    -- splitting data results into 8 byte chunks for tx
    LRbyte6 <= dataResultsStore(55 downto 48);
    LRbyte5 <= dataResultsStore(47 downto 40);
    LRbyte4 <= dataResultsStore(39 downto 32);
    LRbyte3 <= dataResultsStore(31 downto 24);
    LRbyte2 <= dataResultsStore(23 downto 16);
    LRbyte1 <= dataResultsStore(16 downto 8);
    LRbyte0 <= dataResultsStore(7 downto 0);
    -- splitting and also converting the bcd result to an ascii output
    MIbyte2 <= "0011" & maxIndexStore(11 downto 8); --hundreds
    MIbyte1 <= "0011" & maxIndexStore(7 downto 4); --tens
    MIbyte0 <= "0011" & maxIndexStore(3 downto 0); --units

    -- next state logic
    combi_curState: process(clk) --adapted to suit curState only implementation
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '0' THEN --synchronous reset conditions
                curState <= INIT;
                done <= '0';
                txNow <= '0';
                start <= '0';
                numWords <= (others => '0');
            ELSE

                CASE curState IS
                -- assign default values to all outputs to avoid inferred latches
                    curState <= curState; 
                    done <= '0';
                    data <= '0';
                    txNow <= '0';
                    start <= '0';
                    numWords <= '0'

                    WHEN INIT =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF valid='1' AND oe='0' AND fe='0' THEN
                            word <= data;
                            curState <= processWordA;
                        ELSE curState <= init;
                        END IF;

                    WHEN processWordA =>
                        IF word="01100001" OR word="01000001" THEN 
                        a <= word;
                        done <= '1';
                        curState <= nextWordA;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN nextWordA =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF valid='1' AND oe='0' AND fe='0' THEN
                            word <= data;
                            curState <= processWordAN;
                        ELSE curState <= nextWordA;
                        END IF;

                    WHEN processWordAN =>
                        IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                        n1 <= word;
                        done <= '1';
                        curState <= nextWordAN;
                        ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN nextWordAN =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF valid='1' AND oe='0' AND fe='0' THEN
                            word <= data;
                            curState <= processWordANN;
                        ELSE curState <= nextWordAN;
                        END IF;

                    WHEN processWordANN =>
                        IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                        n2 <= word;
                        done <= '1';
                        curState <= nextWordANN;
                        ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN nextWordANN =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF valid='1' AND oe='0' AND fe='0' THEN
                            word <= data;
                            curState <= processWordANNN;
                        ELSE curState <= nextWordANN;
                        END IF;

                    WHEN processWordANNN =>
                        IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                        n3 <= word;
                        start <= '1';
                        curState <= startDataProc;
                        resultsStored <= '0';
                        ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN startDataProc =>
                        start <= '1';
                        curState <= waitDataReady;
                    
                    WHEN waitDataReady =>
                        IF dataReady='0' THEN curState <= waitDataReady;
                        ELSE
                        start <= '0'
                        dataOut <= byte;
                        txNow <= '1';
                        curState <= sendData;
                        END IF;
                    
                    WHEN sendData =>
                        IF txDone='0' THEN curState <= sendData;
                        ELSIF txDone='1' AND seqDone='1' THEN curState <= waitNextWordLP;
                        ELSIF txDone='1' AND seqDone='0' THEN
                        curState <= startDataProc;
                        maxIndexStore <= maxIndex;
                        dataResultsStore <= dataResults;
                        --results stored will bring the flow back to wait for l or p in the event an incomplete ANNN command is input
                        resultsStored <= '1';
                        END IF;

                    WHEN waitNextWordLP =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF valid='1' AND oe='0' AND fe='0' THEN
                            word <= data;
                            curState <= processWordLP;
                        ELSE curState <= waitNextWordLP;
                        END IF;
                    
                    WHEN processWordLP =>
                        --statement to check l or L
                        IF word='01001100' OR '01101100' THEN
                            curState <= listResults;
                        -- statement to check for p or p
                        ELSIF word='01010000' OR '01110000' THEN
                            curState <= peakResults;
                        --statement to check if a or A
                        ELSIF word='01100001' OR word='01000001' THEN
                            curState <= nextWordA;
                        ELSE curState <= processWordLP;
                        END IF;
                    
                    WHEN peakResults =>
                        txCount <= txCount + 1;
                        IF txCount <= 1 THEN
                            txNow <= '1';
                            dataOut <= MIbyte0;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 2 THEN
                            txNow <= '1';
                            dataOut <= MIbyte1;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 3 THEN
                            txNow <= '1';
                            dataOut <= MIbyte2;
                            curState <= txWaitPeak;
                        END IF;
                    
                    WHEN txWaitPeak =>
                        txNow <= '0';
                        IF txCount=3 AND txDone='1' THEN
                            txCount <= 0
                            curState <= waitNextWordLP;
                        ELSIF txCount=2 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=1 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txDone='0'
                            THEN curState <= txWaitPeak;

                    WHEN listResults =>
                        txCount <= txCount + 1;
                        IF txCount <= 1 THEN
                            txNow <= '1';
                            dataOut <= LRbyte0;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 2 THEN
                            txNow <= '1';
                            dataOut <= LRbyte1;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 3 THEN
                            txNow <= '1';
                            dataOut <= LRbyte2;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 4 THEN
                            txNow <= '1';
                            dataOut <= LRbyte3;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 5 THEN
                            txNow <= '1';
                            dataOut <= LRbyte4;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 6 THEN
                            txNow <= '1';
                            dataOut <= LRbyte5;
                            curState <= txWaitPeak;
                        ELSIF txCount <= 7 THEN
                            txNow <= '1';
                            dataOut <= LRbyte6;
                            curState <= txWaitPeak;
                        ELSIF txDone='0'
                            THEN curState <= txWaitList;
                        
                    WHEN txWaitList =>
                        txNow <= '0';
                        IF txCount=7 AND txDone='1' THEN
                            txCount <= '000' 
                            curState <= waitNextWordLP;
                        ELSIF txCount=6 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=5 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=4 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=3 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=2 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=1 AND txDone='1' 
                            THEN curState <= peakResults;
                        ELSIF txDone='0'
                            THEN curState <= txWaitPeak;
            
                END CASE;
            END IF;
        END IF;
    END PROCESS;

END cmdProc;