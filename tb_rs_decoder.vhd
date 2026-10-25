library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rs_decoder is
end entity;

architecture sim of tb_rs_decoder is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';

    signal tx_start, tx_busy, tx_done : std_logic := '0';
    signal rx_start, rx_busy, rx_done : std_logic := '0';

    signal data_in : std_logic_vector(1911 downto 0)
        := (others => '0');

    signal tx_codeword : std_logic_vector(2039 downto 0);
    signal rx_codeword : std_logic_vector(2039 downto 0);

    signal error_detect : std_logic;
    signal correction_valid : std_logic;

begin
    clk <= not clk after 5 ns;

    encoder_inst : entity work.rs_reference_encoder
        port map (
            clk => clk,
            reset => reset,
            start => tx_start,
            data_in => data_in,
            codeword_out => tx_codeword,
            busy => tx_busy,
            done => tx_done
        );

    decoder_inst : entity work.rs_decoder
        port map (
            clk => clk,
            reset => reset,
            start => rx_start,
            codeword_in => tx_codeword,
            codeword_out => rx_codeword,
            busy => rx_busy,
            done => rx_done,
            error_detect => error_detect,
            correction_valid => correction_valid
        );

    process
        variable completed : boolean;
    begin
        report "Starting RS clean-codeword test" severity note;

        reset <= '1';
        wait for 20 ns;
        wait until falling_edge(clk);
        reset <= '0';

        -- Prepare deterministic input data
        for i in 0 to 238 loop
            data_in(1911-8*i downto 1904-8*i) <=
                std_logic_vector(to_unsigned((i*7+3) mod 256, 8));
        end loop;

        -- Start encoder
        wait until falling_edge(clk);
        tx_start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert tx_done = '1'
            report "FAIL: encoder did not complete"
            severity failure;

        wait until falling_edge(clk);
        tx_start <= '0';

        report "Encoder completed" severity note;

        -- Start decoder
        wait until falling_edge(clk);
        rx_start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert rx_busy = '1'
            report "FAIL: decoder did not start"
            severity failure;

        wait until falling_edge(clk);
        rx_start <= '0';

        -- Decoder calculates 16 syndromes before checking
        completed := false;
        for i in 0 to 25 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if rx_done = '1' then
                completed := true;
                exit;
            end if;
        end loop;

        assert completed
            report "FAIL: decoder timeout"
            severity failure;

        assert correction_valid = '1'
            report "FAIL: clean codeword was not accepted"
            severity failure;

        assert error_detect = '0'
            report "FAIL: clean codeword reported an error"
            severity failure;

        assert rx_codeword = tx_codeword
            report "FAIL: decoded codeword differs from encoded codeword"
            severity failure;

        report "PASS: RS clean-codeword test" severity note;
        wait;
    end process;
end architecture;
