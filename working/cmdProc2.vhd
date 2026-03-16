library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cmdProc is
    port (
        clk	: in  std_logic;
        reset	: in  std_logic;

        rxDone	: out std_logic;
        dataIn	: in  std_logic_vector(7 downto 0);
        valid	: in  std_logic;
        oe	: in  std_logic;
        fe	: in  std_logic;

        start   : out std_logic;
        numWords  : out std_logic_vector(11 downto 0);
        dataReady : in  std_logic
    );
end cmdProc;

architecture behavioural of cmdProc is

    type state_type is (
        INIT,
        VALID_CHECKER,
        READ_D1,
        READ_D2,
        READ_D3,
        WAIT_RESULT
    );

    signal curr_state : state_type := INIT;
    signal next_state : state_type := INIT;

    -- Store the three BCD digits
    signal bcd_reg : std_logic_vector(11 downto 0) := (others => '0');

    -- Check whether the received byte is ASCII '0' to '9'
    function is_digit(x : std_logic_vector(7 downto 0)) return boolean is
    begin
        case x is
        when x"30" | x"31" | x"32" | x"33" | x"34" | x"35" | x"36" | x"37" | x"38" | x"39" =>
           return true;
        when others =>
           return false;
        end case;
    end function;

begin

    state_register : process(clk, reset)
    begin
        if reset = '1' then
	curr_state <= INIT;
        bcd_reg <= (others => '0');

        elsif rising_edge(clk) then
            curr_state <= next_state;

            if next_state = INIT then
            -- Clear the stored number when returning to INIT
            bcd_reg <= (others => '0');

            else
                -- Save each digit only in the matching read state
                case curr_state is
                    when READ_D1 =>
                        if valid = '1' and oe = '0' and fe = '0' and is_digit(dataIn) then
                        bcd_reg(11 downto 8) <= dataIn(3 downto 0);
                        end if;

                    when READ_D2 =>
                        if valid = '1' and oe = '0' and fe = '0' and is_digit(dataIn) then
                        bcd_reg(7 downto 4) <= dataIn(3 downto 0);
                        end if;

                    when READ_D3 =>
                        if valid = '1' and oe = '0' and fe = '0' and is_digit(dataIn) then
                        bcd_reg(3 downto 0) <= dataIn(3 downto 0);
                        end if;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    combinational : process(all)
    begin
        next_state <= curr_state;
        rxDone <= '0';
        start <= '0';
        numWords <= bcd_reg;

        case curr_state is

            when INIT =>
                -- Idle state: start=0, numWords=0, rxDone=0
                numWords <= (others => '0');

                -- Move to command checking when a valid byte arrives
                if valid = '1' then
                next_state <= VALID_CHECKER;
                end if;

            when VALID_CHECKER =>
                rxDone <= '1';

                -- Stay here if valid falls low again
                if valid = '0' then
                next_state <= VALID_CHECKER;

                -- UART receive error returns to INIT
                elsif oe = '1' or fe = '1' then
                next_state <= INIT;

                -- Accept only A or a as 
                elsif dataIn = x"41" or dataIn = x"61" then
                next_state <= READ_D1;

                -- Any other command returns to INIT
                else
                next_state <= INIT;
                end if;

            when READ_D1 =>
                rxDone <= '1';

                -- Wait until a new valid digit arrives
                if valid = '0' then
                next_state <= READ_D1;

                -- Error or non-digit then returns to INIT
                elsif oe = '1' or fe = '1' or (not is_digit(dataIn)) then
                next_state <= INIT;

                -- Valid digit goes to the next state
                else
                next_state <= READ_D2;
                end if;

            when READ_D2 =>
                -- Read the second digit
                rxDone <= '1';

                if valid = '0' then
                next_state <= READ_D2;
                elsif oe = '1' or fe = '1' or (not is_digit(dataIn)) then
                next_state <= INIT;
                else
                next_state <= READ_D3;
                end if;

            when READ_D3 =>
                -- Read the third digit
                rxDone <= '1';

                if valid = '0' then
                next_state <= READ_D3;
                elsif oe = '1' or fe = '1' or (not is_digit(dataIn)) then
                next_state <= INIT;
                else
                -- Pulse start when the third digit is accepted
                start <= '1';
                next_state <= WAIT_RESULT;
                end if;

            when WAIT_RESULT =>
                -- Hold the decoded number and wait for the next stage
                numWords <= bcd_reg;

                -- Stay here until dataReady=1
                if dataReady = '1' then
		next_state <= INIT;
                else
		next_state <= WAIT_RESULT;
                end if;

            when others =>
                next_state <= INIT;

        end case;
    end process;

end behavioural;
