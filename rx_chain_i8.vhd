library ieee;
use ieee.std_logic_1164.all;

entity rx_chain_i8 is
    port (
        clk              : in  std_logic;
        reset            : in  std_logic;
        start            : in  std_logic;
        rx_bits          : in  std_logic_vector(32639 downto 0);

        data_out         : out std_logic_vector(15295 downto 0);
        busy             : out std_logic;
        done             : out std_logic;
        error_detect     : out std_logic;
        correction_valid : out std_logic
    );
end entity rx_chain_i8;

architecture rtl of rx_chain_i8 is

    type state_type is (IDLE, WAIT_VITERBI, WAIT_RS, COMPLETE);

    type codeword_array is array (0 to 7) of
        std_logic_vector(2039 downto 0);

    signal state : state_type := IDLE;

    signal vit_start : std_logic := '0';
    signal vit_done  : std_logic;

    signal decoded_bits : std_logic_vector(16319 downto 0);
    signal deinterleaved_bits : std_logic_vector(16319 downto 0);

    signal rs_start : std_logic := '0';
    signal rs_busy  : std_logic_vector(7 downto 0);
    signal rs_done  : std_logic_vector(7 downto 0);
    signal rs_error : std_logic_vector(7 downto 0);
    signal rs_valid : std_logic_vector(7 downto 0);

    signal rs_input  : codeword_array;
    signal rs_output : codeword_array;

    signal data_internal : std_logic_vector(15295 downto 0);

begin

    data_out <= data_internal;

     vit_inst : entity work.viterbi_frame_decoder
        generic map (
            FRAME_BITS => 16320,
            TERMINATED => false
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => vit_start,
            rx_bits      => rx_bits,
            decoded_bits => decoded_bits,
            busy         => open,
            done         => vit_done
        );

    deint_inst : entity work.deinterleaver_i8
        port map (
            data_in  => decoded_bits,
            data_out => deinterleaved_bits
        );

    gen_rs : for i in 0 to 7 generate

        rs_input(i) <=
            deinterleaved_bits(
                16319 - i*2040 downto
                16320 - (i+1)*2040
            );

        rs_inst : entity work.rs_decoder
            port map (
                clk              => clk,
                reset            => reset,
                start            => rs_start,
                codeword_in      => rs_input(i),
                codeword_out     => rs_output(i),
                busy             => rs_busy(i),
                done             => rs_done(i),
                error_detect     => rs_error(i),
                correction_valid => rs_valid(i)
            );

        data_internal(
            15295 - i*1912 downto
            15296 - (i+1)*1912
        ) <= rs_output(i)(2039 downto 128);

    end generate;

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                state             <= IDLE;
                vit_start         <= '0';
                rs_start          <= '0';
                busy              <= '0';
                done              <= '0';
                error_detect      <= '0';
                correction_valid  <= '0';

            else

                vit_start <= '0';
                rs_start  <= '0';
                done      <= '0';

                case state is

                    when IDLE =>
                        busy <= '0';

                        if start = '1' then
                            busy              <= '1';
                            error_detect      <= '0';
                            correction_valid  <= '0';
                            vit_start         <= '1';
                            state             <= WAIT_VITERBI;
                        end if;

                    when WAIT_VITERBI =>
                        if vit_done = '1' then
                            rs_start <= '1';
                            state    <= WAIT_RS;
                        end if;

                    when WAIT_RS =>
                        if rs_done = "11111111" then

                            if rs_error /= "00000000" then
                                error_detect <= '1';
                            end if;

                            if rs_valid = "11111111" then
                                correction_valid <= '1';
                            end if;

                            state <= COMPLETE;
                        end if;

                    when COMPLETE =>
                        busy  <= '0';
                        done  <= '1';
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
