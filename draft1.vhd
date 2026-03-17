library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- COMMON_PACK;
 
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
 
entity data_processor is
    port(
    reset: in std_ulogic;
    clk: in std_ulogic;
    Ctrl_2: in std_ulogic;
    data: in std_ulogic_vector(7 downto 0);
    start: in std_ulogic;
    numWords: in std_ulogic_vector(11 downto 0); -- Binary Coded Decimal
    ----
    Ctrl_1: out std_ulogic;
    dataReady: out std_ulogic;
    byte: out std_ulogic_vector(7 downto 0);
    maxIndex: out std_ulogic_vector(11 downto 0); -- Binary Coded Decimal
    dataResults: out std_ulogic_vector(55 downto 0); -- switch data type here to a "character array" (whatever the fuck that is)
    seqDone: out std_ulogic); -- don't remove this bracket, its for the port function3
end;
------------------------------------------------
architecture arch_mealy of data_processor is
----------------
-- BDC to integer conversion function
function  bcd_to_integer(bcd : std_ulogic_vector(11 downto 0)) return integer is
    variable hundreds : integer;
    variable tens : integer;
    variable ones : integer;
begin
    hundreds := to_integer(unsigned(bcd(11 downto 8)));
    tens := to_integer(unsigned(bcd(7 downto 4)));
    ones := to_integer(unsigned(bcd(3 downto 0)));
    return (hundreds * 100) + (tens * 10) + ones;
end function;
----------------
-- Integer to BCD converter function
function integer_to_bcd(val : integer) return std_ulogic_vector is
    variable hundreds : integer;
    variable tens : integer;
    variable ones : integer;
    variable results : std_ulogic_vector(11 downto 0);
begin
    hundreds := val/100;
    tens := (val mod 100)/10;
    ones := val mod 10;
    results(11 downto 8) := std_ulogic_vector(to_unsigned(hundreds, 4));
    results(7 downto 4) := std_ulogic_vector(to_unsigned(tens, 4));
    results(3 downto 0) := std_ulogic_vector(to_unsigned(ones, 4));
    return results;
end function;
----------------
-- state & signal decleration
type state_type IS (S0, S1, S2, S3, S4);
-- S0 -> Initial & reset state, requests data from data generator
-- S1 -> Recieves Data
-- S2 -> Processes Data
-- S3 -> Shift register
-- S4 -> Outputs results
signal curState, nextState:state_type;
--
type shifting_array is array (0 to 6) of std_ulogic_vector(7 downto 0);
signal shift_register : shifting_array;
signal result_register : shifting_array;
signal post_count: integer range 0 to 3:= 0;
--
signal curNumWords: integer:= 0;
signal numWords_int: integer; -- integer version of the BCD numWords
signal seqDone_sig: std_ulogic;
signal curPeak: std_ulogic_vector(7 downto 0);
signal curPeakIndex: integer:= 0;
signal curPeakIndex_BCD: std_ulogic_vector(11 downto 0); -- BCD version of curPeakIndex
signal updateReg: std_ulogic;
signal Ctrl_2_prev: std_ulogic;
signal Ctrl_1_sig: std_ulogic;
signal reg_full: std_ulogic:= '0';
signal peak_found_proc: std_ulogic:= '0';
signal peak_was_found: std_ulogic:= '0';
----------------
begin
----------------
Ctrl_1 <= Ctrl_1_sig;
numWords_int <= bcd_to_integer(numWords);
curPeakIndex_BCD <= integer_to_bcd(curPeakIndex);
----------------
nexstate: process(curState, curNumWords, numWords_int, start, seqDone_sig, updateReg, Ctrl_2, Ctrl_2_prev)
begin
    case curState is
        when S0 =>
            if start = '1' then
                nextState <= S1;
            else
                nextState <= S0;
            end if;
        when S1 =>
            if Ctrl_2 /= Ctrl_2_prev then
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
            if updateReg = '1' then
                nextState <= S0;
            else
                nextState <= S0;
            end if;
        when S4 =>
            if seqDone_sig = '1' then
                nextState <= S0;
            else
                nextState <= S0;
            end if;
        end case;
end process;
----------------
reset_counter: process(clk, reset)
begin
    if reset = '1' then 
        curState <= S0;
        Ctrl_2_prev <= '0';
        curNumWords <= 0;
        Ctrl_1_sig <= '0';
        peak_was_found <= '0';
        post_count <= 0;
    elsif rising_edge(clk) then
        curState <= nextState;
        Ctrl_2_prev <= Ctrl_2;
        if Ctrl_2 /= Ctrl_2_prev then
            curNumWords <= curNumWords + 1;
        end if;
        if curState = S1 then
            Ctrl_1_sig <= not Ctrl_1_sig;
        end if;
    end if;
end process;
----------------
Outputs: process(clk, reset)
begin
    if reset = '1' then
        dataReady <= '0';
        dataResults <= (others => '0');
        seqDone <= '0';
        seqDone_sig <= '0';
        byte <= (others => '0');
        maxIndex <= (others => '0');
    elsif rising_edge(clk) then
        dataReady <= '0';
        dataResults <= (others => '0');
        seqDone <= '0';
        seqDone_sig <= '0';
        byte <= (others => '0');
        maxIndex <= (others => '0');
        case curState is
            when S1 =>
                byte <= data;
                dataReady <= '1';
            when S4 =>
                seqDone <= '1';
                seqDone_sig <= '1';
                dataResults <= result_register(0) & result_register(1) & result_register(2) & result_register(3) & result_register(4) & result_register(5) & result_register(6);
                maxIndex <= curPeakIndex_BCD;
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
end arch_mealy;
------------------------------------------------
