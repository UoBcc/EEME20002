library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;

entity cmdProc is
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    rxnow         : in  std_logic;
    rxData        : in  std_logic_vector (7 downto 0);
    txData        : out std_logic_vector (7 downto 0);
    rxdone        : out std_logic;
    ovErr         : in  std_logic;
    framErr       : in  std_logic;
    txnow         : out std_logic;
    txdone        : in  std_logic;
    start         : out std_logic;
    numWords_bcd  : out BCD_ARRAY_TYPE(2 downto 0);
    dataReady     : in  std_logic;
    byte          : in  std_logic_vector(7 downto 0);
    maxIndex      : in  BCD_ARRAY_TYPE(2 downto 0);
    dataResults   : in  CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone       : in  std_logic
  );
end entity;

architecture rtl of cmdProc is
  -- Easy-to-change switches (safe defaults for interim TB)

  constant ENABLE_ECHO               : boolean := true;  -- echo typed chars before running
  constant SEND_NEWLINE_BEFORE_START : boolean := false; -- keep FALSE for interim TB safety
  constant DELIM_CHAR                : std_logic_vector(7 downto 0) := x"20"; -- space


  -- Char FIFO (for echo/newline/labels later)
  constant CHAR_FIFO_DEPTH : integer := 64;
  type char_mem_t is array (0 to CHAR_FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
  signal char_mem   : char_mem_t;
  signal char_wr    : integer range 0 to CHAR_FIFO_DEPTH-1 := 0;
  signal char_rd    : integer range 0 to CHAR_FIFO_DEPTH-1 := 0;
  signal char_count : integer range 0 to CHAR_FIFO_DEPTH := 0;


  -- Byte FIFO (buffers bytes from dataReady, decouples fast producer and slow UART)
  constant BYTE_FIFO_DEPTH : integer := 512; -- >= 500
  type byte_mem_t is array (0 to BYTE_FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
  signal byte_mem   : byte_mem_t;
  signal byte_wr    : integer range 0 to BYTE_FIFO_DEPTH-1 := 0;
  signal byte_rd    : integer range 0 to BYTE_FIFO_DEPTH-1 := 0;
  signal byte_count : integer range 0 to BYTE_FIFO_DEPTH := 0;


  -- Command FSM (only implements A/aNNN + streaming bytes for interim)
  type cmd_state_t is (
    C_IDLE,
    C_A_D1,
    C_A_D2,
    C_A_D3,
    C_WAIT_TX_EMPTY,
    C_START_RUN,
    C_RUN
  );
  signal cstate : cmd_state_t := C_IDLE;

  signal num_bcd_reg : BCD_ARRAY_TYPE(2 downto 0) := (others => (others => '0'));

  -- start kept high while printing; drops only after drained
  signal start_reg     : std_logic := '0';
  signal run_active    : std_logic := '0';
  signal seqDone_seen  : std_logic := '0';

  
  -- dataReady edge detect
  signal dataReady_d : std_logic := '0';

  -- TX engine (UART handshake) + byte formatter
  type tx_state_t is (TX_IDLE, TX_PULSE, TX_WAIT);
  signal tx_state   : tx_state_t := TX_IDLE;
  signal txData_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal txnow_reg  : std_logic := '0';

  type fmt_state_t is (FMT_HI, FMT_LO, FMT_DELIM);
  signal fmt_state      : fmt_state_t := FMT_HI;
  signal cur_byte       : std_logic_vector(7 downto 0) := (others => '0');
  signal cur_byte_valid : std_logic := '0';


  -- helpers
  function is_digit(c : std_logic_vector(7 downto 0)) return boolean is
  begin
    return (unsigned(c) >= to_unsigned(48, 8)) and (unsigned(c) <= to_unsigned(57, 8));
  end function;

  function digit_to_bcd(c : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable d : unsigned(3 downto 0);
  begin
    d := unsigned(c(3 downto 0)); -- ASCII '0'..'9' => low nibble is 0..9
    return std_logic_vector(d);
  end function;

  function nibble_to_ascii(n : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable v    : unsigned(3 downto 0);
    variable outv : unsigned(7 downto 0);
  begin
    v := unsigned(n);
    if v < to_unsigned(10,4) then
      outv := to_unsigned(48,8) + resize(v,8); -- '0'
    else
      outv := to_unsigned(55,8) + resize(v,8); -- 'A' (65) - 10
    end if;
    return std_logic_vector(outv);
  end function;

  function inc_ptr(ptr : integer; depth : integer) return integer is
  begin
    if ptr = depth-1 then
      return 0;
    else
      return ptr + 1;
    end if;
  end function;

begin

  -- outputs
  txData       <= txData_reg;
  txnow        <= txnow_reg;
  start        <= start_reg;
  numWords_bcd <= num_bcd_reg;


  -- main sequential
  
  process(clk)
    variable rx_char   : std_logic_vector(7 downto 0);
    variable got_rx    : boolean;
    variable want_send : boolean;
    variable send_char : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then

      -- defaults
      rxdone    <= '0';
      got_rx    := false;
      rx_char   := (others => '0');
      txnow_reg <= '0';

      -- keep last dataReady for edge detect
      dataReady_d <= dataReady;

      if reset = '1' then
        cstate        <= C_IDLE;
        num_bcd_reg   <= (others => (others => '0'));

        start_reg     <= '0';
        run_active    <= '0';
        seqDone_seen  <= '0';
        dataReady_d   <= '0';

        char_wr       <= 0;
        char_rd       <= 0;
        char_count    <= 0;

        byte_wr       <= 0;
        byte_rd       <= 0;
        byte_count    <= 0;

        tx_state      <= TX_IDLE;
        txData_reg    <= (others => '0');

        fmt_state      <= FMT_HI;
        cur_byte       <= (others => '0');
        cur_byte_valid <= '0';

      else


        -- RX handling (only when NOT running; during run behaviour undefined)
        if (rxnow = '1') and (run_active = '0') then
          rxdone  <= '1';
          got_rx  := true;
          rx_char := rxData;

          if ENABLE_ECHO then
            if char_count < CHAR_FIFO_DEPTH then
              char_mem(char_wr) <= rxData;
              char_wr <= inc_ptr(char_wr, CHAR_FIFO_DEPTH);
              char_count <= char_count + 1;
            end if;
          end if;
        end if;

        -- Command FSM: A/a + 3 digits => start run
        case cstate is

          when C_IDLE =>
            if got_rx then
              if (rx_char = x"41") or (rx_char = x"61") then -- 'A' or 'a'
                cstate <= C_A_D1;
              end if;
            end if;

          when C_A_D1 =>
            if got_rx then
              if is_digit(rx_char) then
                num_bcd_reg(2) <= digit_to_bcd(rx_char); -- hundreds
                cstate <= C_A_D2;
              else
                cstate <= C_IDLE;
              end if;
            end if;

          when C_A_D2 =>
            if got_rx then
              if is_digit(rx_char) then
                num_bcd_reg(1) <= digit_to_bcd(rx_char); -- tens
                cstate <= C_A_D3;
              else
                cstate <= C_IDLE;
              end if;
            end if;

          when C_A_D3 =>
            if got_rx then
              if is_digit(rx_char) then
                num_bcd_reg(0) <= digit_to_bcd(rx_char); -- ones

                -- optional newline before start (kept OFF for interim TB)
                if SEND_NEWLINE_BEFORE_START then
                  if char_count <= CHAR_FIFO_DEPTH-2 then
                    char_mem(char_wr) <= x"0A"; -- \n
                    char_mem(inc_ptr(char_wr, CHAR_FIFO_DEPTH)) <= x"0D"; -- \r
                    char_wr <= inc_ptr(inc_ptr(char_wr, CHAR_FIFO_DEPTH), CHAR_FIFO_DEPTH);
                    char_count <= char_count + 2;
                  end if;
                end if;

                cstate <= C_WAIT_TX_EMPTY; -- flush echo/newline before start
              else
                cstate <= C_IDLE;
              end if;
            end if;

          when C_WAIT_TX_EMPTY =>
            if (char_count = 0) and (tx_state = TX_IDLE) and (txdone = '1') then
              cstate <= C_START_RUN;
            end if;

          when C_START_RUN =>
            byte_wr        <= 0;
            byte_rd        <= 0;
            byte_count     <= 0;
            fmt_state      <= FMT_HI;
            cur_byte_valid <= '0';
            seqDone_seen   <= '0';
            dataReady_d    <= '0';

            start_reg  <= '1'; -- keep HIGH during run/printing
            run_active <= '1';
            cstate     <= C_RUN;

          when C_RUN =>
            -- capture bytes
            if (dataReady = '1') and (dataReady_d = '0') then
              if byte_count < BYTE_FIFO_DEPTH then
                byte_mem(byte_wr) <= byte;
                byte_wr <= inc_ptr(byte_wr, BYTE_FIFO_DEPTH);
                byte_count <= byte_count + 1;
              end if;
            end if;

            if seqDone = '1' then
              seqDone_seen <= '1';
            end if;

            -- drop start ONLY after seq done and ALL output drained
            if (seqDone_seen = '1') and (byte_count = 0) and (cur_byte_valid = '0') and (tx_state = TX_IDLE) and (txdone = '1') then
              start_reg  <= '0';
              run_active <= '0';
              cstate     <= C_IDLE;
            end if;

        end case;

        -- TX engine
        -- Priority:
        --   - Not running: drain char FIFO (echo/newline)
        --   - Running: send byte stream as HEX HEX DELIM
        want_send := false;
        send_char := (others => '0');

        if tx_state = TX_IDLE then
          if txdone = '1' then

            -- char fifo only when not running
            if (run_active = '0') and (char_count > 0) then
              want_send := true;
              send_char := char_mem(char_rd);
              char_rd <= inc_ptr(char_rd, CHAR_FIFO_DEPTH);
              char_count <= char_count - 1;

            elsif (run_active = '1') then
              -- latch next byte if needed
              if (cur_byte_valid = '0') and (byte_count > 0) then
                cur_byte <= byte_mem(byte_rd);
                byte_rd <= inc_ptr(byte_rd, BYTE_FIFO_DEPTH);
                byte_count <= byte_count - 1;
                cur_byte_valid <= '1';
                fmt_state <= FMT_HI;
              end if;

              -- emit formatted char
              if cur_byte_valid = '1' then
                want_send := true;
                case fmt_state is
                  when FMT_HI =>
                    send_char := nibble_to_ascii(cur_byte(7 downto 4));
                    fmt_state <= FMT_LO;
                  when FMT_LO =>
                    send_char := nibble_to_ascii(cur_byte(3 downto 0));
                    fmt_state <= FMT_DELIM;
                  when FMT_DELIM =>
                    send_char := DELIM_CHAR;
                    fmt_state <= FMT_HI;
                    cur_byte_valid <= '0';
                end case;
              end if;
            end if;

            if want_send then
              txData_reg <= send_char;
              txnow_reg  <= '1';
              tx_state   <= TX_PULSE;
            end if;

          end if;

        elsif tx_state = TX_PULSE then
          txnow_reg <= '0';
          tx_state  <= TX_WAIT;

        elsif tx_state = TX_WAIT then
          if txdone = '1' then
            tx_state <= TX_IDLE;
          end if;

        end if;

      end if; -- reset
    end if; -- rising edge
  end process;

end architecture;