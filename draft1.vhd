library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

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
    numWords: in std_ulogic_vector(11 downto 0); --Bianary Coded Decimal
    ----
    Ctrl_1: out std_ulogic;
    dataReady: out std_ulogic;
    byte: out std_ulogic_vector(7 downto 0);
    maxIndex: out std_ulogic_vector(11 downto 0); -- Bianary Coded Decimal
    dataResults: out std_ulogic_vector(55 downto 0);
    seqDone: out std_ulogic); -- don't remove this bracket, its for the port function3
end;

architecture arch_mealy of data_processor is
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
signal curNumWords: integer:=0;
signal numWords_int: integer; -- integer version of the BCD numWords
signal seqDone_sig: std_ulogic;
signal curPeak: std_ulogic_vector(7 downto 0);
signal curPeakIndex: integer:=0;
signal curPeakIndex_BCD: std_ulogic_vector(11 downto 0); -- BCD version of curPeakIndex
signal Xn: std_ulogic_vector(7 downto 0);
signal updateReg: std_ulogic;
signal Ctrl_2_prev: std_ulogic;
signal Ctrl_1_sig: std_ulogic;
-- error signals for troubleshooting
signal error_S3_shift: std_ulogic:= '0';
----------------
begin
----------------
Ctrl_1 <= Ctrl_1_sig;
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
                error_S3_shift <= '1';
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
reset_counter: process(clk, reset, Ctrl_2)
begin
    if reset = '1' then
        curState <= S0;
        -- set all signals to zero
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
Outputs: process(data, curState, curPeak, curPeakIndex, Xn)
begin
    dataReady <= '0';
    dataresults <= (others => '0');
    seqDone <= '0';
    seqDone_sig <= '0';
    case curState is
        when S0 => 
            -- no outputs to be driven here
        when S1 =>
            byte <= Xn;
            dataReady <= '1';
        when S2 =>
            -- no outputs to be driven
        when S3 =>
            -- no outputs to be driven here
        when S4 =>
            seqDone <= '1';
            seqDone_sig <= '1';
            -- dataResults <= XXX; this vector need the data processing part and shift register to be completed first.
            maxIndex <= curPeakIndex_BCD;
    end case;
end process;
----------------
DataProcessing: process(clk, curState, Data, curNumWords, curPeakIndex)
begin
    if rising_edge(clk) then
        Xn <= Data;
        if curState = S2 then
            if Xn > curPeak then
                curPeak <= Xn;
                curPeakIndex <= curNumWords;
            elsif Xn < curPeak then
                curPeak <= curPeak;
                curPeakIndex <= curPeakIndex;
            elsif Xn = curPeak then
                curPeak <= Xn;
                curPeakIndex <= curNumWords;
            end if;
        end if;
    end if;
end process;
----------------
shift_register: process(clk, curState)
begin
    if rising_edge(clk) then
        if curState = S3 then 
            -- shift register to be implemented here
            -- updatereg should be driven high here
        end if;
    end if;
end process;
end arch_mealy;

-- TO-DO list:
-- - Shift Register.
-- - converter from integer to BCD.
-- - converter from BCD to integer.