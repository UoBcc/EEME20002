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
        seqDone: in std_logic
    );
end cmdProc;

architecture behavioural of cmdProc is
    type state_type is (
        INIT, START_DATA_PROCESSING, WAIT_FOR_DATA_READY, SEND_DATA, 
        D1, D2, D3, LIST, PEAK, TX_WAIT
    );
    signal curr_state, next_state: state_type;
    signal bcd_reg: std_logic_vector(11 downto 0);
    signal byte_counter: integer range 0 to 7 := 0; 

begin

    state_register: process(clk, reset)
    begin
        if reset = '1' then
            curr_state <= INIT;
            bcd_reg <= (others => '0');
            byte_counter <= 0;
        elsif rising_edge(clk) then
            curr_state <= next_state;

            if valid = '1' and oe = '0' and fe = '0' then
                case curr_state is
                    when D1 => bcd_reg(11 downto 8) <= dataIn(3 downto 0);
                    when D2 => bcd_reg(7 downto 4)  <= dataIn(3 downto 0);
                    when D3 => bcd_reg(3 downto 0)  <= dataIn(3 downto 0);
                    when others => null;
                end case;
            end if;

            if curr_state = TX_WAIT and txDone = '1' then
                if byte_counter < 6 then
                    byte_counter <= byte_counter + 1;
                else
                    byte_counter <= 0;
                end if;
            end if;
        end if;
    end process;
    
    combinational: process(all)
    begin
        -- Default values
        next_state <= curr_state;
        rxDone <= '0';
        start <= '0';
        numWords <= bcd_reg;
        txNow <= '0';
        dataOut <= (others => '0');

        case curr_state is
            when INIT =>
                if valid = '1' then
                    rxDone <= '1';
                    if (oe = '0' and fe = '0') then
                        if (dataIn = x"41" or dataIn = x"61") then next_state <= D1;
                        elsif (dataIn = x"70" or dataIn = x"50") then next_state <= PEAK;
                        elsif (dataIn = x"4C" or dataIn = x"6C") then next_state <= LIST;
                        end if;
                    end if;
                end if;

            when D1 | D2 | D3 =>
                if valid = '1' then
                    rxDone <= '1';
                    if (oe = '1' or fe = '1') then next_state <= INIT;
                    elsif curr_state = D1 then next_state <= D2;
                    elsif curr_state = D2 then next_state <= D3;
                    else next_state <= START_DATA_PROCESSING;
                    end if;
                end if;

            when START_DATA_PROCESSING =>
                start <= '1';
                next_state <= WAIT_FOR_DATA_READY;

            when WAIT_FOR_DATA_READY =>
                if seqDone = '1' then next_state <= INIT; end if;

            when PEAK | LIST =>
                next_state <= SEND_DATA;

            when SEND_DATA =>
                if txDone = '1' then
                    txNow <= '1';
                    case byte_counter is
                        when 0 => dataOut <= dataResults(55 downto 48);
                        when 1 => dataOut <= dataResults(47 downto 40);
                        when 2 => dataOut <= dataResults(39 downto 32);
                        when 3 => dataOut <= dataResults(31 downto 24);
                        when 4 => dataOut <= dataResults(23 downto 16);
                        when 5 => dataOut <= dataResults(15 downto 8);
                        when 6 => dataOut <= dataResults(7 downto 0);
                        when others => dataOut <= x"00";
                    end case;
                    next_state <= TX_WAIT;
                end if;

            when TX_WAIT =>
                if txDone = '1' then
                    if byte_counter = 0 then
                        next_state <= INIT;
                    else
                        next_state <= SEND_DATA;
                    end if;
                end if;

            when others =>
                next_state <= INIT;
        end case;
    end process;
end behavioural;
