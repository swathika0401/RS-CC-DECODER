library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_chain_i8 is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        start    : in  std_logic;

        data_in  : in  std_logic_vector(15295 downto 0);
        tx_bits  : out std_logic_vector(32639 downto 0);

        busy     : out std_logic;
        done     : out std_logic
    );
end entity tx_chain_i8;

architecture rtl of tx_chain_i8 is

    type state_type is (
        IDLE,
        START_RS,
        WAIT_RS,
        PREPARE,
        PREPARE_WAIT,
        SEND_BITS,
        WAIT_CC,
        COMPLETE
    );

    type codeword_array is array (0 to 7)
        of std_logic_vector(2039 downto 0);

    signal state : state_type := IDLE;

    signal codewords : codeword_array :=
        (others => (others => '0'));

    signal rs_input    : std_logic_vector(1911 downto 0);
    signal rs_codeword : std_logic_vector(2039 downto 0);
    signal rs_start    : std_logic := '0';
    signal rs_done     : std_logic;
    signal rs_busy     : std_logic;

    signal cc_data      : std_logic := '0';
    signal cc_valid     : std_logic := '0';
    signal cc_code      : std_logic_vector(1 downto 0);
    signal cc_valid_out : std_logic;

    signal tx_reg : std_logic_vector(32639 downto 0) :=
        (others => '0');

    signal interleaved : std_logic_vector(16319 downto 0) :=
        (others => '0');

    signal code_index      : integer range 0 to 7 := 0;
    signal symbol_index    : integer range 0 to 254 := 0;
    signal codeword_select : integer range 0 to 7 := 0;

    signal bit_index : integer range 0 to 16320 := 0;
    signal cc_count  : integer range 0 to 16320 := 0;

    signal busy_i : std_logic := '0';
    signal done_i : std_logic := '0';

begin

    ----------------------------------------------------------------
    -- Select one 239-byte data block for the RS encoder
    ----------------------------------------------------------------

    rs_input <= data_in(
        15295 - code_index * 1912 downto
        15296 - (code_index + 1) * 1912
    );

    ----------------------------------------------------------------
    -- Reed-Solomon encoder
    ----------------------------------------------------------------

    rs_inst : entity work.rs_reference_encoder
        port map (
            clk         => clk,
            reset       => reset,
            start       => rs_start,
            data_in     => rs_input,
            codeword_out => rs_codeword,
            busy        => rs_busy,
            done        => rs_done
        );

    ----------------------------------------------------------------
    -- Convolutional encoder, rate 1/2
    ----------------------------------------------------------------

    cc_inst : entity work.cc_encoder_ref
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => cc_data,
            valid_in  => cc_valid,
            code_out  => cc_code,
            valid_out => cc_valid_out
        );

    ----------------------------------------------------------------
    -- Transmitter controller
    ----------------------------------------------------------------

    process(clk)
        variable symbol_pos : integer;
        variable bit_pos    : integer;
    begin
        if rising_edge(clk) then

            if reset = '1' then

                state            <= IDLE;
                code_index       <= 0;
                symbol_index     <= 0;
                codeword_select  <= 0;
                bit_index        <= 0;
                cc_count         <= 0;

                rs_start <= '0';
                cc_data  <= '0';
                cc_valid <= '0';

                interleaved <= (others => '0');
                tx_reg      <= (others => '0');

                busy_i <= '0';
                done_i <= '0';

            else

                rs_start <= '0';
                cc_valid <= '0';
                done_i   <= '0';

                ----------------------------------------------------
                -- Store each convolutionally encoded output pair
                ----------------------------------------------------

                if cc_valid_out = '1' and cc_count < 16320 then

                    tx_reg(
                        32639 - 2 * cc_count downto
                        32638 - 2 * cc_count
                    ) <= cc_code;

                    cc_count <= cc_count + 1;

                end if;

                ----------------------------------------------------
                -- Main state machine
                ----------------------------------------------------

                case state is

                    when IDLE =>

                        if start = '1' then
                            busy_i          <= '1';
                            code_index      <= 0;
                            symbol_index    <= 0;
                            codeword_select <= 0;
                            bit_index       <= 0;
                            cc_count        <= 0;

                            tx_reg      <= (others => '0');
                            interleaved <= (others => '0');

                            state <= START_RS;
                        end if;


                    when START_RS =>

                        rs_start <= '1';
                        state    <= WAIT_RS;


                    when WAIT_RS =>

                        if rs_done = '1' then

                            codewords(code_index) <= rs_codeword;

                            if code_index = 7 then

                                symbol_index    <= 0;
                                codeword_select <= 0;
                                state           <= PREPARE;

                            else

                                code_index <= code_index + 1;
                                state      <= START_RS;

                            end if;

                        end if;


                    when PREPARE =>

                        -- One 8-bit symbol from each RS codeword
                        -- is placed into the depth-8 interleaver.

                        symbol_pos := 2039 - symbol_index * 8;

                        bit_pos := 16319 -
                            (symbol_index * 64 +
                             codeword_select * 8);

                        interleaved(
                            bit_pos downto bit_pos - 7
                        ) <= codewords(codeword_select)(
                            symbol_pos downto symbol_pos - 7
                        );

                        if codeword_select = 7 then

                            codeword_select <= 0;

                            if symbol_index = 254 then

                                bit_index <= 0;
                                state     <= PREPARE_WAIT;

                            else

                                symbol_index <= symbol_index + 1;

                            end if;

                        else

                            codeword_select <= codeword_select + 1;

                        end if;


                    when PREPARE_WAIT =>

                        -- Allow the final scheduled interleaver
                        -- signal assignment to settle.

                        bit_index <= 0;
                        state     <= SEND_BITS;


                    when SEND_BITS =>

                        if bit_index < 16320 then

                            cc_data  <= interleaved(16319 - bit_index);
                            cc_valid <= '1';

                            bit_index <= bit_index + 1;

                            if bit_index = 16319 then
                                state <= WAIT_CC;
                            end if;

                        end if;


                    when WAIT_CC =>

                        if cc_count = 16320 then
                            state <= COMPLETE;
                        end if;


                    when COMPLETE =>

                        busy_i <= '0';
                        done_i <= '1';
                        state  <= IDLE;


                end case;

            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------

    tx_bits <= tx_reg;
    busy    <= busy_i;
    done    <= done_i;

end architecture rtl;
