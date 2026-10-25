library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_full_i8 is
end entity tb_full_i8;

architecture sim of tb_full_i8 is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal original_data : std_logic_vector(15295 downto 0)
        := (others => '0');

    signal tx_bits : std_logic_vector(32639 downto 0);
    signal tx_busy : std_logic;
    signal tx_done : std_logic;

    -- Channel buffer for injecting a transmission error
    signal channel_bits : std_logic_vector(32639 downto 0)
        := (others => '0');

    signal rx_start : std_logic := '0';

    signal rx_data : std_logic_vector(15295 downto 0);
    signal rx_busy : std_logic;
    signal rx_done : std_logic;
    signal rx_error : std_logic;
    signal rx_correction_valid : std_logic;

begin

    clk <= not clk after 5 ns;

    -- Depth-8 transmitter
    tx_inst : entity work.tx_chain_i8
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            data_in => original_data,
            tx_bits => tx_bits,
            busy    => tx_busy,
            done    => tx_done
        );

    -- Depth-8 receiver
    rx_inst : entity work.rx_chain_i8
        port map (
            clk              => clk,
            reset            => reset,
            start            => rx_start,
            rx_bits          => channel_bits,
            data_out         => rx_data,
            busy             => rx_busy,
            done             => rx_done,
            error_detect     => rx_error,
            correction_valid => rx_correction_valid
        );

    stimulus : process
        variable data_temp : std_logic_vector(15295 downto 0);
    begin

        report "Starting depth-8 RS + CC single-bit error test"
            severity note;

        -- Generate deterministic input: eight RS data blocks
        for i in 0 to 1911 loop
            data_temp(15295 - 8*i downto 15288 - 8*i) :=
                std_logic_vector(to_unsigned((i*7 + 3) mod 256, 8));
        end loop;

        original_data <= data_temp;

        -- Reset sequence
        wait for 30 ns;
        wait until rising_edge(clk);
        reset <= '0';

        -- Start transmitter
        wait until rising_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        start <= '0';

        -- Wait for transmitter completion
        wait until tx_done = '1' for 1 ms;

        if tx_done /= '1' then
            assert false
                report "FAIL: depth-8 transmitter timed out"
                severity failure;
            std.env.stop;
            wait;
        end if;

        report "Depth-8 transmitter completed"
            severity note;

        -- Copy completed encoded stream into the channel buffer
        channel_bits <= tx_bits;
        wait for 1 ns;

        -- Flip exactly one transmitted bit
        channel_bits(100) <= not channel_bits(100);

        report "Single-bit channel error injected"
            severity note;

        -- Start receiver after the corrupted stream is ready
        wait until rising_edge(clk);
        rx_start <= '1';

        wait until rising_edge(clk);
        rx_start <= '0';

        -- Wait for receiver completion
        wait until rx_done = '1' for 2 ms;

        if rx_done /= '1' then
            assert false
                report "FAIL: depth-8 receiver timed out"
                severity failure;
            std.env.stop;
            wait;
        end if;

        wait for 1 ns;

             -- TEMPORARY: Find the first mismatching bit
        for i in 15295 downto 0 loop
            if rx_data(i) /= original_data(i) then
                report "First mismatch at bit index " &
                    integer'image(i) &
                    ", expected=" & std_logic'image(original_data(i)) &
                    ", actual=" & std_logic'image(rx_data(i))
                    severity note;
                exit;
            end if;
        end loop;

        assert rx_data = original_data
            report "FAIL: recovered data differs after single-bit error"
            severity failure;
        report "PASS: depth-8 receiver recovered original data after single-bit error"
            severity note;

        std.env.stop;
        wait;

    end process;

end architecture sim;
