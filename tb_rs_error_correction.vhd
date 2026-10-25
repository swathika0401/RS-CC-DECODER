library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_rs_error_correction is
end entity;

architecture sim of tb_rs_error_correction is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;
    signal tx_done  : std_logic;

    signal rx_start : std_logic := '0';
    signal rx_busy  : std_logic;
    signal rx_done  : std_logic;

    signal data_in : std_logic_vector(1911 downto 0)
        := (others => '0');

    signal tx_codeword : std_logic_vector(2039 downto 0);

    signal rx_input_codeword : std_logic_vector(2039 downto 0)
        := (others => '0');

    signal rx_codeword : std_logic_vector(2039 downto 0);

    signal error_detect     : std_logic;
    signal correction_valid : std_logic;

begin

    clk <= not clk after 5 ns;

    -- RS(255,239) reference encoder
    encoder_inst : entity work.rs_reference_encoder
        port map (
            clk          => clk,
            reset        => reset,
            start        => tx_start,
            data_in      => data_in,
            codeword_out => tx_codeword,
            busy         => tx_busy,
            done         => tx_done
        );

    -- RS(255,239) decoder under test
    decoder_inst : entity work.rs_decoder
        port map (
            clk              => clk,
            reset            => reset,
            start            => rx_start,
            codeword_in      => rx_input_codeword,
            codeword_out     => rx_codeword,
            busy             => rx_busy,
            done             => rx_done,
            error_detect     => error_detect,
            correction_valid => correction_valid
        );

    stimulus : process
        variable original_word  : std_logic_vector(2039 downto 0);
        variable corrupted_word : std_logic_vector(2039 downto 0);
        variable completed      : boolean;
    begin

        report "Starting RS single-symbol correction test"
            severity note;

        -- Reset
        reset <= '1';
        wait for 20 ns;
        wait until falling_edge(clk);
        reset <= '0';

        -- Generate deterministic input data
        for i in 0 to 238 loop
            data_in(1911-8*i downto 1904-8*i) <=
                std_logic_vector(
                    to_unsigned((i*7+3) mod 256, 8)
                );
        end loop;

        -- Start RS encoder
        wait until falling_edge(clk);
        tx_start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert tx_done = '1'
            report "FAIL: RS encoder did not complete"
            severity failure;

        original_word := tx_codeword;

        report "RS codeword generated successfully"
            severity note;

        wait until falling_edge(clk);
        tx_start <= '0';

        -- Inject one bit error in first RS symbol
        corrupted_word := original_word;
        corrupted_word(2039) := not original_word(2039);

        rx_input_codeword <= corrupted_word;

        assert corrupted_word /= original_word
            report "FAIL: error injection unsuccessful"
            severity failure;

        report "One bit error injected into first RS symbol"
            severity note;

        -- Start RS decoder
        wait until falling_edge(clk);
        rx_start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert rx_busy = '1'
            report "FAIL: RS decoder did not start"
            severity failure;

        wait until falling_edge(clk);
        rx_start <= '0';

        -- Wait for RS decoder completion
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
            report "FAIL: RS decoder timed out"
            severity failure;

        -- Verify error detection
        assert error_detect = '1'
            report "FAIL: RS error not detected"
            severity failure;

        -- Verify correction
        assert correction_valid = '1'
            report "FAIL: RS correction unsuccessful"
            severity failure;

        -- Compare corrected and original codewords
        assert rx_codeword = original_word
            report "FAIL: corrected RS codeword differs from original"
            severity failure;

        report "PASS: RS detected and corrected single-symbol error"
            severity note;

        --std.env.stop;
report "PASS: RS detected and corrected single-symbol error";
wait;


    end process;

end architecture sim;
