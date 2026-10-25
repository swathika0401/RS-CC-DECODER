library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_full_rx_error is
end entity;

architecture sim of tb_full_rx_error is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal original_data : std_logic_vector(1911 downto 0)
                           := (others => '0');

    signal tx_bits : std_logic_vector(4079 downto 0);
    signal tx_bits_with_error : std_logic_vector(4079 downto 0);
    signal tx_busy : std_logic;
    signal tx_done : std_logic;

    signal rx_data : std_logic_vector(1911 downto 0);
    signal rx_busy : std_logic;
    signal rx_done : std_logic;
    signal rx_error : std_logic;
    signal rx_correction_valid : std_logic;
    signal rx_start : std_logic := '0';

begin

    clk <= not clk after 5 ns;

    -- Inject exactly one channel-bit error into the completed transmit frame.
    process(tx_bits)
    variable error_mask : std_logic_vector(4079 downto 0);
begin
    error_mask := (others => '0');
    error_mask(1000) := '1';
    tx_bits_with_error <= tx_bits xor error_mask;
end process;

    tx_inst : entity work.tx_chain
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            data_in => original_data,
            tx_bits => tx_bits,
            busy    => tx_busy,
            done    => tx_done
        );

    rx_inst : entity work.rx_chain
        port map (
            clk               => clk,
            reset             => reset,
            start             => rx_start,
            rx_bits           => tx_bits_with_error,
            data_out          => rx_data,
            busy              => rx_busy,
            done              => rx_done,
            error_detect      => rx_error,
            correction_valid  => rx_correction_valid
        );

    stimulus : process
        variable data_temp : std_logic_vector(1911 downto 0);
    begin

        report "Starting full RS + CC receiver test with one channel-bit error"
            severity note;

        -- Generate deterministic 239-byte input
        for i in 0 to 238 loop
            data_temp(1911-8*i downto 1904-8*i) :=
                std_logic_vector(to_unsigned((i*7+3) mod 256, 8));
        end loop;

        original_data <= data_temp;

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset <= '0';

        -- Start transmitter
        wait until rising_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        start <= '0';

        -- Wait for transmitter completion, with timeout
        for i in 0 to 5000 loop
            wait until rising_edge(clk);
            exit when tx_done = '1';
        end loop;

        assert tx_done = '1'
            report "FAIL: transmitter did not complete"
            severity failure;

        report "Transmitter completed"
            severity note;

        -- Start receiver after complete frame is available
        wait until rising_edge(clk);
        rx_start <= '1';

        wait until rising_edge(clk);
        rx_start <= '0';

        -- Wait for receiver completion, with timeout
        for i in 0 to 10000 loop
            wait until rising_edge(clk);
            exit when rx_done = '1';
        end loop;

        assert rx_done = '1'
            report "FAIL: receiver did not complete"
            severity failure;

        wait for 1 ns;

        -- Verify the original data is recovered after channel-bit error.
        assert rx_data = original_data
            report "FAIL: recovered data does not match original data after channel-bit error"
            severity failure;

        assert rx_correction_valid = '1'
            report "FAIL: receiver did not report valid RS correction"
            severity failure;

        report "PASS: complete RS + CC chain recovered original data with one channel-bit error"
            severity note;

        wait;
    end process;

end architecture sim;
