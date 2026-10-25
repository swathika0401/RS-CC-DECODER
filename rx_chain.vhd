library ieee;
use ieee.std_logic_1164.all;

entity rx_chain is
    port (
        clk              : in  std_logic;
        reset            : in  std_logic;
        start            : in  std_logic;
        rx_bits          : in  std_logic_vector(4079 downto 0);

        data_out         : out std_logic_vector(1911 downto 0);
        busy             : out std_logic;
        done             : out std_logic;
        error_detect     : out std_logic;
        correction_valid : out std_logic
    );
end entity rx_chain;

architecture rtl of rx_chain is

    type state_type is (IDLE, WAIT_VITERBI, WAIT_RS, COMPLETE);
    signal state : state_type := IDLE;

    signal vit_start : std_logic := '0';
    signal vit_busy  : std_logic;
    signal vit_done  : std_logic;

    signal decoded_bits      : std_logic_vector(2039 downto 0);
    signal deinterleaved_bits : std_logic_vector(2039 downto 0);

    signal rs_start : std_logic := '0';
    signal rs_busy  : std_logic;
    signal rs_done  : std_logic;

    signal corrected_codeword : std_logic_vector(2039 downto 0);
    signal rs_error           : std_logic;
    signal rs_correction_valid : std_logic;

begin

    vit_inst : entity work.viterbi_frame_decoder
        generic map (
            FRAME_BITS => 2040
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => vit_start,
            rx_bits      => rx_bits,
            decoded_bits => decoded_bits,
            busy         => vit_busy,
            done         => vit_done
        );

    deint_inst : entity work.deinterleaver
        port map (
            data_in  => decoded_bits,
            data_out => deinterleaved_bits
        );

    rs_inst : entity work.rs_decoder
        port map (
            clk              => clk,
            reset            => reset,
            start            => rs_start,
            codeword_in      => deinterleaved_bits,
            codeword_out     => corrected_codeword,
            busy             => rs_busy,
            done             => rs_done,
            error_detect     => rs_error,
            correction_valid => rs_correction_valid
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state            <= IDLE;
                vit_start        <= '0';
                rs_start         <= '0';
                busy             <= '0';
                done             <= '0';
                data_out         <= (others => '0');
                error_detect     <= '0';
                correction_valid <= '0';

            else
                vit_start <= '0';
                rs_start  <= '0';

                case state is

                    when IDLE =>
                        busy <= '0';

                        if start = '1' then
                            busy             <= '1';
                            done             <= '0';
                            error_detect     <= '0';
                            correction_valid <= '0';
                            vit_start        <= '1';
                            state            <= WAIT_VITERBI;
                        end if;

                    when WAIT_VITERBI =>
                        if vit_done = '1' then
                            rs_start <= '1';
                            state    <= WAIT_RS;
                        end if;

                    when WAIT_RS =>
                        if rs_done = '1' then
                            data_out         <= corrected_codeword(2039 downto 128);
                            error_detect     <= rs_error;
                            correction_valid <= rs_correction_valid;
                            state            <= COMPLETE;
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
