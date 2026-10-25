library ieee;
use ieee.std_logic_1164.all;

entity tb_one_rs_elab is
end entity;

architecture sim of tb_one_rs_elab is
    signal clk              : std_logic := '0';
    signal reset            : std_logic := '1';
    signal start            : std_logic := '0';
    signal codeword_in      : std_logic_vector(2039 downto 0)
                             := (others => '0');
    signal codeword_out     : std_logic_vector(2039 downto 0);
    signal busy             : std_logic;
    signal done             : std_logic;
    signal error_detect     : std_logic;
    signal correction_valid : std_logic;
begin

    clk <= not clk after 5 ns;

    uut : entity work.rs_decoder
        port map (
            clk              => clk,
            reset            => reset,
            start            => start,
            codeword_in      => codeword_in,
            codeword_out     => codeword_out,
            busy             => busy,
            done             => done,
            error_detect     => error_detect,
            correction_valid => correction_valid
        );

    process
    begin
        wait for 20 ns;
        report "ONE RS DECODER ELABORATION TEST STARTED";
        wait;
    end process;

end architecture;
