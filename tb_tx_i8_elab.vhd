library ieee;
use ieee.std_logic_1164.all;

entity tb_tx_i8_elab is
end entity;

architecture sim of tb_tx_i8_elab is
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal start   : std_logic := '0';
    signal data_in : std_logic_vector(15295 downto 0)
                     := (others => '0');
    signal tx_bits : std_logic_vector(32639 downto 0);
    signal busy    : std_logic;
    signal done    : std_logic;
begin

    dut : entity work.tx_chain_i8
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            data_in => data_in,
            tx_bits => tx_bits,
            busy    => busy,
            done    => done
        );

end architecture;
