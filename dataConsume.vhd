vhdllibrary IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common_pack.all; --  gives us BCD_ARRAY_TYPE and CHAR_ARRAY_TYPE not vector

--  renamed from data_processor to dataConsume, all std_ulogic changed to std_logic and Ctrl_1 Ctrl_2 renamed to ctrlOut ctrlIn,
--  numWords changed to numWords_bcd and type changed to BCD_ARRAY_TYPE
entity dataConsume is
    port(
    reset: in std_logic;
    clk: in std_logic;
    ctrlIn: in std_logic;
    data: in std_logic_vector(7 downto 0);
    start: in std_logic;
    numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
    ----
-- maxIndex type changed from vector(11 downto 0) to BCD_ARRAY_TYPE 
-- dataResults type changed from vector(55 downto 0) to CHAR_ARRAY_TYPE
   
    ctrlOut: out std_logic;
    dataReady: out std_logic;
    byte: out std_logic_vector(7 downto 0);
    maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
    dataResults: out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone: out std_logic);
end;
------------------------------------------------
 -- renamed from arch_mealy to Behavioral to match testbench
architecture  Behavioral of dataConsume is
----------------
--  bcd_to_integer now takes BCD_ARRAY_TYPE instead of vector
-- before: bcd(11 downto 8), bcd(7 downto 4), bcd(3 downto 0)
-- after:  bcd(2),           bcd(1),           bcd(0)
function bcd_to_integer(bcd : BCD_ARRAY_TYPE(2 downto 0)) return integer is
    variable hundreds : integer;
    variable tens : integer;
    variable ones : integer;
begin
    hundreds := to_integer(unsigned(bcd(2))); -- was bcd(11 downto 8)
    tens     := to_integer(unsigned(bcd(1))); -- was bcd(7 downto 4)
    ones     := to_integer(unsigned(bcd(0))); -- was bcd(3 downto 0)
    return (hundreds * 100) + (tens * 10) + ones;
end function;
----------------
-- integer_to_bcd now returns BCD_ARRAY_TYPE instead of vector
-- before: returned std_ulogic_vector(11 downto 0)
-- after:  returns BCD_ARRAY_TYPE(2 downto 0)
function integer_to_bcd(val : integer) return BCD_ARRAY_TYPE is
    variable hundreds : integer;
    variable tens : integer;
    variable ones : integer;
    variable results : BCD_ARRAY_TYPE(2 downto 0); -- was std_ulogic_vector(11 downto 0)
begin
    hundreds := val/100;
    tens := (val mod 100)/10;
    ones := val mod 10;
    results(2) := std_logic_vector(to_unsigned(hundreds, 4)); -- was results(11 downto 8)
    results(1) := std_logic_vector(to_unsigned(tens, 4));     -- was results(7 downto 4)
    results(0) := std_logic_vector(to_unsigned(ones, 4));     -- was results(3 downto 0)
    return results;
end function;
----------------
-- state & signal decleration & small changes form ulogic to logic
type state_type IS (S0, S1, S2, S3, S4);
-- S0 -> Initial & reset state, requests data from data generator
-- S1 -> Recieves Data
-- S2 -> Processes Data
-- S3 -> Shift register
-- S4 -> Outputs results
signal curState, nextState:state_type;
--
type shifting_array is array (0 to 6) of std_logic_vector(7 downto 0); -- CHANGE 12: std_ulogic_vector to std_logic_vector
signal shift_register : shifting_array;
signal result_register : shifting_array;
signal post_count: integer range 0 to 3:= 0;
--
signal curNumWords: integer:= 0;
signal numWords_int: integer;
signal seqDone_sig: std_logic;          
signal curPeak: std_logic_vector(7 downto 0);
signal curPeakIndex: integer:= 0;
signal updateReg: std_logic;         
signal ctrlIn_prev: std_logic;         
signal ctrlOut_sig: std_logic;          
signal reg_full: std_logic:= '0';       
signal peak_found_proc: std_logic:= '0';
signal peak_was_found: std_logic:= '0'; 
----------------
begin
----------------
ctrlOut <= ctrlOut_sig; --  was Ctrl_1 <= Ctrl_1_sig
numWords_int <= bcd_to_integer(numWords_bcd); -- was bcd_to_integer(numWords)
--  curPeakIndex_BCD is now done inside integer_to_bcd directly
----------------
nexstate: process(curState, curNumWords, numWords_int, start, seqDone_sig, updateReg, ctrlIn, ctrlIn_prev)
begin
    case curState is
        when S0 =>
            if start = '1' then
                nextState <= S1;
            else
                nextState <= S0;
            end if;
        when S1 =>
            if ctrlIn /= ctrlIn_prev then -- CHANGE 14: was Ctrl_2 /= Ctrl_2_prev
                nextState <= S2;
            else
                nextState <= S1;
            end if;
        when S2 =>
            if curNumWords < numWords_int then
                nextState <= S3;
            else
                nextState <= S4;
            end if;
        when S3 =>
            -- was nextState <= S0  XXXXXX here BIG BUG FIX
            -- going to S0 was restarting the whole sequence every word!
            -- must go to S1 to request the next word
            nextState <= S1;
        when S4 =>
            nextState <= S0;
        end case;
end process;
----------------
reset_counter: process(clk, reset)
begin
    if reset = '1' then 
        curState <= S0;
        ctrlIn_prev <= '0';   
        curNumWords <= 0;
        ctrlOut_sig <= '0';   
        peak_was_found <= '0';
        post_count <= 0;
    elsif rising_edge(clk) then
        curState <= nextState;
        ctrlIn_prev <= ctrlIn; 
        if ctrlIn /= ctrlIn_prev then 
            curNumWords <= curNumWords + 1;
        end if;
        -- reset word counter for new sequence
        if curState = S0 then
            curNumWords <= 0;
        end if;
        -- ctrlOut toggle fixed
        -- before: toggled in S1 (wrong, was toggling every cycle in S1)
        -- after: toggle once when entering S1, and after S3 to request next word
        if (curState = S0 and nextState = S1) or curState = S3 then
            ctrlOut_sig <= not ctrlOut_sig;
        end if;
    end if;
end process;
----------------
-- YOUR OUTPUTS PROCESS KEPT, small changes only
Outputs: process(clk, reset)
begin
    if reset = '1' then
        dataReady <= '0';
        dataResults <= (others => (others => '0')); -- (others => '0'), needs two levels for array of vectors
        seqDone <= '0';
        seqDone_sig <= '0';
        byte <= (others => '0');
        maxIndex <= (others => (others => '0')); -- same as above
    elsif rising_edge(clk) then
        dataReady <= '0';
        seqDone <= '0';
        seqDone_sig <= '0';
        byte <= (others => '0');
        case curState is
            when S1 =>
                byte <= data;
                dataReady <= '1';
            when S4 =>
                seqDone <= '1';
                seqDone_sig <= '1';
                dataResults <= result_register; -- it was concatenating vectors, now direct array assign
                maxIndex <= integer_to_bcd(curPeakIndex); -- now returns BCD_ARRAY_TYPE directly
            when others => null;
        end case;
    end if;
end process;
----------------
DataProcessing_comp: process(curState, data, curPeak)
begin
    peak_found_proc <= '0';
    if curState = S2 then
        if data > curPeak then
            peak_found_proc <= '1';
        elsif data = curPeak then
            peak_found_proc <= '1';
        elsif data < curPeak then
            peak_found_proc <= '0';
        end if;
    end if;
end process;
------
DataProcessing_assign: process(clk, curState, Data, curNumWords, shift_register, curPeak, peak_found_proc)
begin
    if rising_edge(clk) then
        if curState = S0 then
            peak_was_found <= '0';
            updateReg <= '0';
        end if;
        if curState = S2 then
            if peak_found_proc = '1' then
                curPeak <= data;
                curPeakIndex <= curNumWords;
                result_register(0 to 2) <= shift_register(0 to 2);
                result_register(3) <= curPeak;
            elsif peak_found_proc = '0' then
                curPeak <= curPeak;
                curPeakIndex <= curPeakIndex;
            end if;
        end if;
    
        if curState = S2 then
            shift_register(0) <= data;
            shift_register(1 to 6) <= shift_register(0 to 5);
            if peak_found_proc = '1' then 
                peak_was_found <= '1';
                post_count <= 0;
            end if;
        elsif curState = S3 then
            updateReg <= '1';
            if peak_was_found = '1' then
                post_count <= post_count + 1;
                result_register(4 + post_count) <= data;                
                if post_count = 2 then
                    reg_full <= '1';
                end if;
            end if;
        end if;
    end if;
end process;
----------------
end  Behavioral;
------------------------------------------------
