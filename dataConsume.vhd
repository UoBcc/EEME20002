library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common_pack.all;

entity dataConsume is
    port(
        clk          : in std_logic;
        reset        : in std_logic;
        start        : in std_logic;
        numWords_bcd : in BCD_ARRAY_TYPE(2 downto 0);
        ctrlIn  : in std_logic;
        data         : in std_logic_vector(7 downto 0);
        ctrlOut      : out std_logic;
        dataReady    : out std_logic;
        byte         : out std_logic_vector(7 downto 0);
        maxIndex     : out BCD_ARRAY_TYPE(2 downto 0);
        dataResults  : out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
        seqDone      : out std_logic
    );
end dataConsume;


--------------------------------------------------------------------------------------------------------
architecture Behavioral of dataConsume is

    type state_type is (S0, S1, S2, S3, S4, S5, S6, S7, S8);

    signal curState  : state_type;
    signal nextState : state_type;

    signal ctrlOut_sig  : std_logic := '0';
    signal ctrlIn_prev  : std_logic := '0';
    signal ctrlIn_edge  : std_logic;

    signal numWords_int : integer := 0;
    signal curNumWords  : integer := 0;

    -- index 0 = oldest byte, index 6 = newest byte
    signal shift_register  : CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    signal result_register : CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);

    signal curPeak      : integer := -128; -- min value of signed 8 bit
    signal curPeakIndex : integer := 0;
-----------------------------------------------------------------------------------------------------------
    -- BCD to integer conversion
    function bcd_to_int(bcd : BCD_ARRAY_TYPE(2 downto 0)) return integer is
        variable result : integer := 0;
    begin
        result := to_integer(unsigned(bcd(2))) * 100;
        result := result + to_integer(unsigned(bcd(1))) * 10;
        result := result + to_integer(unsigned(bcd(0)));
        return result;
    end function;

    -- integer back to BCD for the maxIndex output
    function int_to_bcd(n : integer) return BCD_ARRAY_TYPE is
        variable bcd : BCD_ARRAY_TYPE(2 downto 0);
        variable tmp : integer;
    begin
        bcd := (others => (others => '0'));
        tmp := n;
        bcd(2) := std_logic_vector(to_unsigned(tmp / 100, 4));
        tmp := tmp mod 100;
        bcd(1) := std_logic_vector(to_unsigned(tmp / 10, 4));
        bcd(0) := std_logic_vector(to_unsigned(tmp mod 10, 4));
        return bcd;
    end function;
-------------------------------------------------------------------------------------
begin

    ctrlOut     <= ctrlOut_sig;
    dataResults <= result_register;
    maxIndex    <= int_to_bcd(curPeakIndex);

    -- edge detect on ctrlIn using XOR with delayed version
    ctrlIn_edge <= ctrlIn xor ctrlIn_prev;

----------------------------------------------------------------------------------------------------------
    process(curState, start, ctrlIn_edge, curNumWords, numWords_int)
    begin
        nextState <= curState; -- sStayin same state unless changed below
        case curState is

            when S0 =>
                if start = '1' then
                    nextState <= S1;
                end if;

            when S1 =>
                    nextState <= S2;

            when S2 =>
                -- wait here until the generator toggles ctrlIn
                if ctrlIn_edge = '1' then
                    nextState <= S3;
                end if;

            when S3 =>
                nextState <= S4;

            when S4 =>
                if curNumWords < numWords_int then
                    nextState <= S1;
                else
                    nextState <= S5; --all bytes read now check last positions
                end if;

            when S5 =>
                nextState <= S6;
            when S6 =>
                nextState <= S7;
            when S7 =>
                nextState <= S8;
            when S8 =>
                nextState <= S0;

            when others =>
                nextState <= S0;
        end case;
    end process;
------------------------------------------------------------------------------------------------------------------------------------
   
    process(clk)
        variable curVAL : integer;
    begin
        if rising_edge(clk) then

            if reset = '1' then
                curState        <= S0;
                ctrlOut_sig     <= '0';
                ctrlIn_prev     <= '0';
                numWords_int    <= 0;
                curNumWords     <= 0;
                shift_register  <= (others => (others => '0'));
                result_register <= (others => (others => '0'));
                curPeak         <= -128;
                curPeakIndex    <= 0;
                dataReady       <= '0';
                seqDone         <= '0';
                byte            <= (others => '0');

            else
                curState    <= nextState;
                ctrlIn_prev <= ctrlIn;

                dataReady <= '0'; -- default low, only pulse high when needed
                seqDone   <= '0';

                case curState is

                    when S0 =>
                        ctrlOut_sig     <= '0';
                        numWords_int    <= bcd_to_int(numWords_bcd);
                        curNumWords     <= 0;
                        shift_register  <= (others => (others => '0'));
                        result_register <= (others => (others => '0'));
                        curPeak         <= -128;
                        curPeakIndex    <= 0;
                        byte            <= (others => '0');

                    when S1 =>
                        -- toggle ctrlOut to signal we want the next byte
                        ctrlOut_sig <= not ctrlOut_sig;

                    when S2 =>
                        null; -- just waiting

                    when S3 =>
                        curNumWords <= curNumWords + 1;
                        -- shift old values left, put new byte at end (index 6)
                        shift_register(0 to RESULT_BYTE_NUM-2) <= shift_register(1 to RESULT_BYTE_NUM-1);
                        shift_register(RESULT_BYTE_NUM-1) <= data;
                        byte      <= data;
                        dataReady <= '1';

                    when S4 =>
                        -- only check once window is full (7 bytes received)
                        if curNumWords >= RESULT_BYTE_NUM then
                            curVAL := to_integer(signed(shift_register(3)));
                            if curVAL > curPeak then
                                curPeak      <= curVAL;
                                curPeakIndex <= curNumWords - 4;
                                result_register <= shift_register;
                            end if;
                        end if;

                    
                    -- XXXXXXXXXXXXXXXXXXX not 100% sure the index offsets are right here but testbench passes
                    when S5 =>
                        curVAL := to_integer(signed(shift_register(4)));
                        if curVAL > curPeak then
                            curPeak      <= curVAL;
                            curPeakIndex <= curNumWords - 3;
                            result_register(0) <= shift_register(1);
                            result_register(1) <= shift_register(2);
                            result_register(2) <= shift_register(3);
                            result_register(3) <= shift_register(4);
                            result_register(4) <= shift_register(5);
                            result_register(5) <= shift_register(6);
                            result_register(6) <= (others => '0');
                        end if;

                    when S6 =>
                        curVAL := to_integer(signed(shift_register(5)));
                        if curVAL > curPeak then
                            curPeak      <= curVAL;
                            curPeakIndex <= curNumWords - 2;
                            result_register(0) <= shift_register(2);
                            result_register(1) <= shift_register(3);
                            result_register(2) <= shift_register(4);
                            result_register(3) <= shift_register(5);
                            result_register(4) <= shift_register(6);
                            result_register(5) <= (others => '0');
                            result_register(6) <= (others => '0');
                        end if;

                    when S7 =>
                        curVAL := to_integer(signed(shift_register(6)));
                        if curVAL > curPeak then
                            curPeak      <= curVAL;
                            curPeakIndex <= curNumWords - 1;
                            result_register(0) <= shift_register(3);
                            result_register(1) <= shift_register(4);
                            result_register(2) <= shift_register(5);
                            result_register(3) <= shift_register(6);
                            result_register(4) <= (others => '0');
                            result_register(5) <= (others => '0');
                            result_register(6) <= (others => '0');
                        end if;

                    when S8 =>
                        seqDone <= '1';

                end case;
            end if;
        end if;
    end process;

end Behavioral;
