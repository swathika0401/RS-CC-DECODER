library ieee;
use ieee.std_logic_1164.all;

entity tb_eight_rs_elab is
end entity;

architecture sim of tb_eight_rs_elab is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    type codeword_array is array (0 to 7) of
        std_logic_vector(2039 downto 0);

    signal codeword_in  : codeword_array := (others => (others => '0'));
    signal codeword_out : codeword_array;
    signal busy         : std_logic_vector(7 downto 0);
    signal done         : std_logic_vector(7 downto 0);
    signal error_detect : std_logic_vector(7 downto 0);
    signal correction_valid : std_logic_vector(7 downto 0);
begin
    clk <= not clk after 5 ns;

    gen_rs : for i in 0 to 7 generate
        uut : entity work.rs_decoder
            port map (
                clk              => clk,
                reset            => reset,
                start            => start,
                codeword_in      => codeword_in(i),
                codeword_out     => codeword_out(i),
                busy             => busy(i),
                done             => done(i),
                error_detect     => error_detect(i),
                correction_valid => correction_valid(i)
            );
    end generate;

    process
    begin
        wait for 20 ns;
        report "EIGHT RS DECODERS ELABORATION TEST STARTED";
        wait;
    end process;
end architecture;
