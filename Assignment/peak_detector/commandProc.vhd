library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;


entity cmdProc is
    Port ( rxnow : in STD_LOGIC;
           ovErr : in STD_LOGIC;
           framErr : in STD_LOGIC;
           rxData : in STD_LOGIC_VECTOR (7 downto 0);
           rxdone : out STD_LOGIC;

           txdone : in STD_LOGIC;
           txData : out STD_LOGIC_VECTOR (7 downto 0);
           txnow : out STD_LOGIC;

           dataReady : in STD_LOGIC;
           byte : in STD_LOGIC_VECTOR (7 downto 0);
           maxIndex : in BCD_ARRAY_TYPE (2 downto 0);
           dataResults : in CHAR_ARRAY_TYPE (0 to RESULT_BYTE_NUM-1);
           seqDone : in STD_LOGIC;
           start : out  STD_LOGIC;
           numWords_bcd : out BCD_ARRAY_TYPE (2 downto 0);
 
           clk : in STD_LOGIC;
           reset : in STD_LOGIC);
end cmdProc;

ARCHITECTURE FSM of cmdProc is
    TYPE state_type is (INIT, nextWordA, nextWordAN, nextWordANN, processWordA, processWordAN, processWordANN, processWordANNN, startDataProc, waitDataReady, sendData, waitNextWordLP, processWordLP, peakResults, txWaitPeak, listResults, txWaitList);

    SIGNAL curState: STATE_TYPE := INIT; --converted to curState only single FSM to avoid inferred latches from curState and nextState FSM design from TB1 labs

    SIGNAL word : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL a : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n1 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n3 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); --init all ascii signals

    SIGNAL maxIndexStore : BCD_ARRAY_TYPE(2 downto 0) := (others => (others => '0'));
    SIGNAL dataResultsStore : CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) := (others => (others => '0')); --init rxData stores

    SIGNAL resultsStored : STD_LOGIC := '0';
    SIGNAL txCount : unsigned(2 downto 0) := "000"; --init "counters" (resultsStored counts as a counter right?)

    SIGNAL MIbyte0, MIbyte1, MIbyte2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL LRbyte0, LRbyte1, LRbyte2, LRbyte3, LRbyte4, LRbyte5, LRbyte6 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    
    

BEGIN
    -- concurrent calculations
    numWords_bcd <= n1(3 downto 0) & n2(3 downto 0) & n3(3 downto 0);
    -- splitting rxData results into 8 byte chunks for tx
    LRbyte6 <= dataResultsStore(0);
    LRbyte5 <= dataResultsStore(1);
    LRbyte4 <= dataResultsStore(2);
    LRbyte3 <= dataResultsStore(3);
    LRbyte2 <= dataResultsStore(4);
    LRbyte1 <= dataResultsStore(5);
    LRbyte0 <= dataResultsStore(6);
    -- splitting and also converting the bcd result to an ascii output
    MIbyte2 <= "0011" & maxIndexStore(2); --hundreds
    MIbyte1 <= "0011" & maxIndexStore(1); --tens
    MIbyte0 <= "0011" & maxIndexStore(0); --units

    -- next state logic
    combi_curState: process(clk) --adapted to suit curState only implementation
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '0' THEN --synchronous reset conditions
                curState <= INIT;
                rxdone <= '0';
                txnow <= '0';
                start <= '0';
                numWords_bcd <= (others => '0');
            ELSE
                curState <= curState; 
                rxdone <= '0';
                txnow <= '0';
                start <= '0';

                CASE curState IS
                -- assign default values to all outputs to avoid inferred latches

                    WHEN INIT =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF rxnow='1' AND ovErr='0' AND framErr='0' THEN
                            word <= rxData;
                            curState <= processWordA;
                        ELSE curState <= init;
                        END IF;

                    WHEN processWordA =>
                        IF word="01100001" OR word="01000001" THEN 
                        a <= word;
                        rxdone <= '1';
                        curState <= nextWordA;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN nextWordA =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF rxnow='1' AND ovErr='0' AND framErr='0' THEN
                            word <= rxData;
                            curState <= processWordAN;
                        ELSE curState <= nextWordA;
                        END IF;

                    WHEN processWordAN =>
                        IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                        n1 <= word;
                        rxdone <= '1';
                        curState <= nextWordAN;
                        ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN nextWordAN =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF rxnow='1' AND ovErr='0' AND framErr='0' THEN
                            word <= rxData;
                            curState <= processWordANN;
                        ELSE curState <= nextWordAN;
                        END IF;

                    WHEN processWordANN =>
                        IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                        n2 <= word;
                        rxdone <= '1';
                        curState <= nextWordANN;
                        ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                        ELSE curState <= INIT;
                        END IF;
                    
                    WHEN nextWordANN =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF rxnow='1' AND ovErr='0' AND framErr='0' THEN
                            word <= rxData;
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
                        start <= '0';
                        txData <= byte;
                        txnow <= '1';
                        curState <= sendData;
                        END IF;
                    
                    WHEN sendData =>
                        IF txdone='0' THEN curState <= sendData;
                        ELSIF txdone='1' AND seqDone='1' THEN curState <= waitNextWordLP;
                        ELSIF txdone='1' AND seqDone='0' THEN
                        curState <= startDataProc;
                        maxIndexStore <= maxIndex;
                        dataResultsStore <= dataResults;
                        --results stored will bring the flow back to wait for l or p in the event an incomplete ANNN command is input
                        resultsStored <= '1';
                        END IF;

                    WHEN waitNextWordLP =>
                        IF reset='0' THEN curState <= INIT;
                        ELSIF rxnow='1' AND ovErr='0' AND framErr='0' THEN
                            word <= rxData;
                            curState <= processWordLP;
                        ELSE curState <= waitNextWordLP;
                        END IF;
                    
                    WHEN processWordLP =>
                        --statement to check l or L
                        IF word="01001100" OR word="01101100" THEN
                            curState <= listResults;
                        -- statement to check for p or p
                        ELSIF word="01010000" OR word="01110000" THEN
                            curState <= peakResults;
                        --statement to check if a or A
                        ELSIF word="01100001" OR word="01000001" THEN
                            curState <= nextWordA;
                        ELSE curState <= processWordLP;
                        END IF;
                    
                    WHEN peakResults =>
                        IF txdone='1' THEN --had to wrap the peak/listresults cases in a txdone check to make sure the flow doesn't fall through due to the slow speed of the UART
                            txCount <= txCount + 1;
                            IF txCount = 0 THEN
                                txnow <= '1';
                                txData <= MIbyte0;
                                curState <= txWaitPeak;
                            ELSIF txCount = 1 THEN
                                txnow <= '1';
                                txData <= MIbyte1;
                                curState <= txWaitPeak;
                            ELSIF txCount = 2 THEN
                                txnow <= '1';
                                txData <= MIbyte2;
                                curState <= txWaitPeak;
                            END IF;
                        ELSE curState <= peakResults;
                        END IF;
                    WHEN txWaitPeak =>
                        txnow <= '0';
                        IF txCount=2 AND txdone='1' THEN
                            txCount <= "000";
                            curState <= waitNextWordLP;
                        ELSIF txCount=1 AND txdone='1' 
                            THEN curState <= peakResults;
                        ELSIF txCount=0 AND txdone='1' 
                            THEN curState <= peakResults;
                        ELSIF txdone='0'
                            THEN curState <= txWaitPeak;
                        END IF;

                    WHEN listResults =>
                        IF txdone = '1' THEN
                            txCount <= txCount + 1;
                            IF txCount = 0 THEN
                                txnow <= '1';
                                txData <= LRbyte0;
                                curState <= txWaitList;
                            ELSIF txCount = 1 THEN
                                txnow <= '1';
                                txData <= LRbyte1;
                                curState <= txWaitList;
                            ELSIF txCount = 2 THEN
                                txnow <= '1';
                                txData <= LRbyte2;
                                curState <= txWaitList;
                            ELSIF txCount = 3 THEN
                                txnow <= '1';
                                txData <= LRbyte3;
                                curState <= txWaitList;
                            ELSIF txCount = 4 THEN
                                txnow <= '1';
                                txData <= LRbyte4;
                                curState <= txWaitList;
                            ELSIF txCount = 5 THEN
                                txnow <= '1';
                                txData <= LRbyte5;
                                curState <= txWaitList;
                            ELSIF txCount = 6 THEN
                                txnow <= '1';
                                txData <= LRbyte6;
                                curState <= txWaitList;
			    END IF;
                        ELSE curState <= listResults;
                        END IF;
                        
                    WHEN txWaitList =>
                        txnow <= '0';
                        IF txCount=6 AND txdone='1' THEN
                            txCount <= "000";
                            curState <= waitNextWordLP;
                        ELSIF txCount=5 AND txdone='1' 
                            THEN curState <= listResults;
                        ELSIF txCount=4 AND txdone='1' 
                            THEN curState <= listResults;
                        ELSIF txCount=3 AND txdone='1' 
                            THEN curState <= listResults;
                        ELSIF txCount=2 AND txdone='1' 
                            THEN curState <= listResults;
                        ELSIF txCount=1 AND txdone='1' 
                            THEN curState <= listResults;
                        ELSIF txCount=0 AND txdone='1' 
                            THEN curState <= listResults;
                        ELSIF txdone='0'
                            THEN curState <= txWaitList;
                        END IF;
            
                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;