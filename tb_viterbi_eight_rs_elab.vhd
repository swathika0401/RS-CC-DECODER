library ieee;
use ieee.std_logic_1164.all;

entity tb_viterbi_eight_rs_elab is
end entity;

architecture sim of tb_viterbi_eight_rs_elab is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal rx_bits : std_logic_vector(32639 downto 0)
                   := (others => '0');

    signal decoded_bits : std_logic_vector(16319 downto 0);
    signal vit_done     : std_logic;
    signal vit_busy     : std_logic;

    type codeword_array is array (0 to 7) of
        std_logic_vector(2039 downto 0);

    signal codeword_in  : codeword_array
                        := (others => (others => '0'));
    signal codeword_out : codeword_array;

    signal rs_busy : std_logic_vector(7 downto 0);
    signal rs_done : std_logic_vector(7 downto 0);
    signal rs_error : std_logic_vector(7 downto 0);
    signal rs_valid : std_logic_vector(7 downto 0);

begin

    clk <= not clk after 5 ns;

    vit_inst : entity work.viterbi_frame_decoder
        generic map (
            FRAME_BITS => 16320
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            rx_bits      => rx_bits,
            decoded_bits => decoded_bits,
            busy         => vit_busy,
            done         => vit_done
        );

    gen_rs : for i in 0 to 7 generate
        rs_inst : entity work.rs_decoder
            port map (
                clk              => clk,
                reset            => reset,
                start            => start,
                codeword_in      => codeword_in(i),
                codeword_out     => codeword_out(i),
                busy             => rs_busy(i),
                done             => rs_done(i),
                error_detect     => rs_error(i),
                correction_valid => rs_valid(i)
            );
    end generate;

    process
    begin
        wait for 20 ns;
        report "VITERBI PLUS EIGHT RS ELABORATION TEST STARTED";
        wait;
    end process;

end architecture;
