library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;


entity cmdProc is
    port (
             clk:		in std_logic;
             reset:		in std_logic;
             rxnow:		in std_logic; --valid
             rxData:			in std_logic_vector (7 downto 0);
             txData:			out std_logic_vector (7 downto 0);
             rxdone:		out std_logic;
             ovErr:		in std_logic;
             framErr:	in std_logic;
             txnow:		out std_logic;
             txdone:		in std_logic;
             start: out std_logic;
             numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
             dataReady: in std_logic;
             byte: in std_logic_vector(7 downto 0);
             maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
             dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
             seqDone: in std_logic
               );
             
end cmdProc;

ARCHITECTURE FSM of cmdProc is
    TYPE state_type is (INIT, NOTA, nextWordA, nextWordAN, nextWordANN, processWordA, processWordAN, processWordANN, processWordANNN, startDataProc, waitDataReady, txWaitDataLo, txWaitDataHi, sendData, waitNextWordLP, processWordLP);

    SIGNAL curState: STATE_TYPE := INIT; --converted to curState only single FSM to avoid inferred latches from curState and nextState FSM design from TB1 labs

    SIGNAL word : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL a : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n1 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL n3 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); --init all ascii signals

    SIGNAL maxIndexStore : BCD_ARRAY_TYPE(2 downto 0) := (others => (others => '0'));
    SIGNAL dataResultsStore : CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) := (others => (others => '0')); --init rxData stores
    
    SIGNAL isL : STD_LOGIC := '0';
    SIGNAL isP : STD_LOGIC := '0';
    SIGNAL isA : STD_LOGIC := '0';
    SIGNAL resultsStored : STD_LOGIC := '0';
    SIGNAL txCount : unsigned(2 downto 0) := "000"; --init "counters" (resultsStored counts as a counter right?)

    SIGNAL MIbyte0, MIbyte1, MIbyte2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL LRbyte0, LRbyte1, LRbyte2, LRbyte3, LRbyte4, LRbyte5, LRbyte6, LRbyte7, LRbyte8, LRbyte9, LRbyte10, LRbyte11, LRbyte12, LRbyte13 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL LRbyteCount : unsigned(2 downto 0) := "000";
    SIGNAL LRbyteHi, LRbyteLo : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    SIGNAL byteHi, byteLo : std_logic_vector(7 downto 0);
    
    SIGNAL seqDoneDelayed : std_logic := '0';
    SIGNAL seqDoneLatch : std_logic := '0';
    
    

BEGIN
    -- concurrent calculations
    numWords_bcd(2) <= n1(3 downto 0);
    numWords_bcd(1) <= n2(3 downto 0);
    numWords_bcd(0) <= n3(3 downto 0);
    -- splitting rxData results into 8 byte chunks for tx
    LRbyte0 <= dataResultsStore(0);
    LRbyte1 <= dataResultsStore(1);
    LRbyte2 <= dataResultsStore(2);
    LRbyte3 <= dataResultsStore(3);
    LRbyte4 <= dataResultsStore(4);
    LRbyte5 <= dataResultsStore(5);
    LRbyte6 <= dataResultsStore(6);
    -- reformat LRbytes into 2 hex chars for each LRbyte
    LRbyteHi <= "0011" & dataResultsStore(to_integer(LRbyteCount))(7 downto 4) when unsigned(dataResultsStore(to_integer(LRbytecount))( 7 downto 4)) <= 9 ELSE
              std_logic_vector(to_unsigned(to_integer(unsigned(dataResultsStore(to_integer(LRbytecount))(7 downto 4))) + 55, 8));
    LRbyteLo <= "0011" & dataResultsStore(to_integer(LRbyteCount))(3 downto 0) when unsigned(dataResultsStore(to_integer(LRbytecount))( 3 downto 0)) <= 9 ELSE
              std_logic_vector(to_unsigned(to_integer(unsigned(dataResultsStore(to_integer(LRbytecount))(3 downto 0))) + 55, 8));    
    -- splitting and also converting the bcd result to an ascii output
    MIbyte0 <= "0011" & maxIndexStore(2); --hundreds
    MIbyte1 <= "0011" & maxIndexStore(1); --tens
    MIbyte2 <= "0011" & maxIndexStore(0); --units
    --splits raw bytes to hex ascii
    byteHi <= "0011" & byte(7 downto 4) when unsigned(byte( 7 downto 4)) <= 9 ELSE
              std_logic_vector(to_unsigned(to_integer(unsigned(byte(7 downto 4))) + 55, 8));
    byteLo <= "0011" & byte(3 downto 0) when unsigned(byte( 3 downto 0)) <= 9 ELSE
              std_logic_vector(to_unsigned(to_integer(unsigned(byte(3 downto 0))) + 55, 8));

    -- next state logic
    combi_curState: process(clk) --adapted to suit curState only implementation
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN --synchronous reset conditions
                curState <= INIT;
                rxdone <= '0';
                txnow <= '0';
                start <= '0';
                resultsStored <= '0';
            ELSE
                seqDoneDelayed <= seqDone;
                IF seqDone = '1' AND seqDoneDelayed = '0' THEN 
                    seqDoneLatch <= '1';
                    maxIndexStore <= maxIndex;
                    dataResultsStore <= dataResults;                
                END IF;

                rxdone <= '0';
                txnow <= '0';
                start <= '0';

                CASE curState IS
                -- assign default values to all outputs to avoid inferred latches

                    WHEN INIT =>
                        rxdone<='0';
                        IF rxnow='1' AND framErr='0' THEN
                            word <= rxData;
                            curState <= processWordA;
                            rxdone <= '1';
                        ELSE curState <= init;
                        END IF;
                        
                    WHEN NOTA =>
                        rxdone <= '0';
                        curState <= INIT;

                    WHEN processWordA =>
                        IF rxnow = '1' THEN
                            IF word="01100001" OR word="01000001" THEN 
                                curState <= nextWordA;
                                isA <= '1'; isL <= '0'; isP <= '0';
                            ELSE 
                                curState <= NOTA;
                                rxDone<= '0';
                            END IF;
                        ELSE 
                            rxdone <= '0';
                            IF word="01100001" OR word="01000001" THEN
                                curstate <= nextWordA;
                                isA <= '1';
                            ELSE 
                                curstate <= NOTA;
                            END IF;
                        END IF;
                    
                    WHEN nextWordA =>
                        rxdone <= '0';
                        IF rxnow='1' AND framErr='0' THEN
                            word <= rxData;                           
                            curState <= processWordAN;
                            rxdone<='1';
                        ELSE
                        END IF;

                    WHEN processWordAN =>
                        IF rxnow = '1' THEN
                            rxdone <= '1';
                            curstate <= processWordAN;
                        ELSE 
                            rxdone <= '0';
                            IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                                n1 <= word;
                                curState <= nextWordAN;
                            ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                            ELSE curState <= INIT;
                                rxdone <= '0';
                            END IF;
                        END IF;
                    
                    WHEN nextWordAN =>
                        rxdone <= '0';
                        IF rxnow='1' AND framErr='0' THEN
                            word <= rxdata;
                            rxdone <= '1';
                            curState <= processWordANN;
                        END IF;

                    WHEN processWordANN =>
                        IF rxnow='1' THEN
                            rxdone <= '1';
                            curState <= processWordANN;
                        ELSE
                            rxdone <= '0';                        
                            IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                                n2 <= word;
                                curState <= nextWordANN;
                            ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                            ELSE curState <= INIT;
                            END IF;
                        END IF;
                    
                    WHEN nextWordANN =>
                        rxdone <= '0';
                        IF rxnow='1' AND framErr='0' THEN
                            word <= rxData;
                            rxdone <= '1';
                            curState <= processWordANNN;
                        END IF;

                    WHEN processWordANNN =>
                        IF rxnow='1' THEN
                            rxdone <= '1';
                            curState <= processWordANNN;
                        ELSE
                            rxdone <= '0';
                            IF unsigned(word)>="00110000" AND unsigned(word)<="00111001" THEN
                                n3 <= word;
                                curState <= startDataProc;
                                resultsStored <= '0';
                                seqDoneLatch <= '0';
                            ELSIF resultsStored='1' THEN curState <= waitNextWordLP;
                            ELSE curState <= INIT;
                            END IF;
                        END IF;
                    
                    WHEN startDataProc =>
                        start <= '1';
                        curState <= waitDataReady;
                    
                    WHEN waitDataReady =>
                        IF dataready = '0' THEN curState <= waitdataready; start <= '0';
                        ELSE
                            start <= '0';
                            txcount <= "000";
                            curstate <= sendData;
                        END IF;
      

                    WHEN waitNextWordLP =>
                        rxdone<='0';
                        IF rxnow='1' AND framErr='0' THEN
                            word <= rxData;
                            curState <= processWordLP;
                            rxdone <= '1';
                        ELSE curState <= waitNextWordLP;
                        END IF;
                    
                    
                    WHEN processWordLP =>
                        IF rxnow = '1' THEN
                            rxdone <= '1';
                            curstate <= processwordlp;
                        ELSE 
                            rxdone <= '0';
                            --statement to check l or L
                            IF word="01001100" OR word="01101100" THEN
                                curState <= sendData;
                                isA <= '0'; isL <= '1'; isP <= '0';
                                txcount <= "000";
                                LRbyteCount <= "000";
                            --statement to check p or P
                            ELSIF word="01010000" OR word="01110000" THEN
                                curState <= sendData;
                                isA <= '0'; 
                                isL <= '0'; 
                                isP <= '1';
                                txcount <= "000";
                            --statement to check a or A done
                            ELSIF word="01100001" OR word="01000001" THEN 
                                curState <= nextWordA;
                                isA <= '1'; isL <= '0'; isP <= '0';
                            ELSE 
                                curState <= waitNextWordLP;
                            END IF;
                        END IF;

                    
                    WHEN sendData =>
                        IF txdone='1' then
                            txcount <= txcount + 1;
                            txnow <= '1';
                            curstate <= txwaitdatalo;
                            IF isA = '1' THEN    
                                if txcount = 0 then txData <= byteHI;
                                elsif txcount = 1 then txdata <= bytelo;
                                elsif txcount = 2 then txdata <= "00100000";
                                END IF;
                            ELSIF isP = '1' THEN
                                IF txcount = 0 THEN txdata <= MIbyte0;
                                ELSIF txcount = 1 THEN txdata <= MIbyte1;
                                ELSIF txcount = 2 THEN txdata <= MIbyte2;
                                ELSIF txcount= 3 THEN txdata <= "00100000";
                                END IF;
                            ELSIF isL = '1' THEN
                                IF txcount = 0 THEN txdata <= LRbyteHi;
                                ELSIF txcount = 1 THEN txdata <= LRbyteLo;
                                ELSIF txcount = 2 THEN txdata <= "00100000";
                                END IF;                                        
                            END IF;
                        ELSE
                        curstate <= sendData;
                        END IF;
                   
                   WHEN txWaitDataLo =>
                        txnow <= '0';
                        IF txdone = '0' then
                            curstate <= txWaitDataHi;
                        ELSE curstate <= txWaitDataLo;
                        END IF;
                   
                   WHEN txWaitDataHi =>
                        IF txdone = '1' then
                            IF isA = '1' THEN
                                IF txcount = 3 THEN
                                    txcount <= "000";
                                    IF seqDonelatch = '1' then
                                        curstate <= waitNextWordLP;
                                        resultsStored <= '1';
                                        seqDoneLatch <= '0';
                                    ELSE curState <= startDataProc;
                                    END IF;
                                ELSE curState <= sendData;
                                END IF;
                            
                            ELSIF isP = '1' THEN
                                IF txcount = 4 THEN
                                    txcount <= "000";
                                    curstate <= waitnextwordLP;
                                ELSE curstate <= senddata;
                                END IF;
                            
                            ELSIF isL= '1' THEN
                                IF txcount = 3 THEN
                                    txcount <= "000";
                                    IF LRbyteCount = 6 THEN
                                        LRbyteCount <= "000";
                                        curState <= waitNextWordLP;
                                    ELSE
                                        LRbyteCount <= LRbyteCount + 1;
                                        curState <= sendData;
                                    END IF;
                                ELSE
                                    curState <= sendData;
                                END IF;
                            END IF;
                        ELSE curState <= txWaitDataHi;
                        END IF;
                    
                    WHEN OTHERS =>
                        curState <= INIT;
            
                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;