library ieee;
use ieee.std_logic_1164.all;

entity tb_rx_i8_elab is
end entity;

architecture sim of tb_rx_i8_elab is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal rx_bits : std_logic_vector(32639 downto 0)
        := (others => '0');
    signal data_out : std_logic_vector(15295 downto 0);
    signal busy : std_logic;
    signal done : std_logic;
    signal error_detect : std_logic;
    signal correction_valid : std_logic;
begin
    clk <= not clk after 5 ns;

    dut : entity work.rx_chain_i8
        port map (
            clk              => clk,
            reset            => reset,
            start            => start,
            rx_bits          => rx_bits,
            data_out         => data_out,
            busy             => busy,
            done             => done,
            error_detect     => error_detect,
            correction_valid => correction_valid
        );
end architecture;
