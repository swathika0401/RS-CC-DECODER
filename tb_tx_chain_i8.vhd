library ieee;
use ieee.std_logic_1164.all;

entity tb_tx_chain_i8 is
end entity tb_tx_chain_i8;

architecture sim of tb_tx_chain_i8 is

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal data_in : std_logic_vector(15295 downto 0)
        := (others => '0');

    signal tx_bits : std_logic_vector(32639 downto 0);
    signal busy : std_logic;
    signal done : std_logic;

begin

    clk <= not clk after 5 ns;

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

    stimulus : process
    begin
        report "TEST START" severity note;

        -- Apply reset
        wait for 20 ns;
        wait until rising_edge(clk);
        reset <= '0';

        -- Apply start pulse
        wait until rising_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        start <= '0';

        -- Allow the transmitter time to operate
        wait for 100 us;

        -- Check status at a fixed time
        if done = '1' then
            report "TRANSMITTER DONE" severity note;
        else
            report "TRANSMITTER NOT DONE YET" severity note;
        end if;

        report "TEST FINISHED" severity note;
        wait;
    end process;

end architecture sim;
