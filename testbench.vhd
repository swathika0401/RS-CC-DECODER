library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_simple_test is
end entity tb_simple_test;

architecture sim of tb_simple_test is

    signal rx_bits : std_logic_vector(27 downto 0);
    signal decoded_bits : std_logic_vector(13 downto 0);

    constant MESSAGE : std_logic_vector(13 downto 0) :=
        "10110010000000";

    constant CODEWORD : std_logic_vector(27 downto 0) :=
        "1011011100001010000101001001";

    -- RS clock and reset
    signal rs_clk   : std_logic := '0';
    signal rs_reset : std_logic := '1';

    -- RS encoder signals
    signal rs_enc_start : std_logic := '0';
    signal rs_enc_busy  : std_logic;
    signal rs_enc_done  : std_logic;
    signal rs_data : std_logic_vector(1911 downto 0) :=
        (others => '0');
    signal rs_encoded : std_logic_vector(2039 downto 0);

    -- RS decoder signals
    signal rs_start : std_logic := '0';
    signal rs_codeword : std_logic_vector(2039 downto 0) :=
        (others => '0');
    signal rs_busy : std_logic;
    signal rs_done : std_logic;
    signal rs_error_detect : std_logic;
    signal rs_correction_valid : std_logic;
    signal rs_corrected_codeword :
        std_logic_vector(2039 downto 0);

begin

    -- Convolutional decoder
    uut: entity work.viterbi_decoder
        port map (
            rx_bits => rx_bits,
            decoded_bits => decoded_bits
        );

    -- RS clock
    rs_clk <= not rs_clk after 5 ns;

    -- Reference RS encoder
    rs_encoder_inst: entity work.rs_reference_encoder
        port map (
            clk => rs_clk,
            reset => rs_reset,
            start => rs_enc_start,
            data_in => rs_data,
            codeword_out => rs_encoded,
            busy => rs_enc_busy,
            done => rs_enc_done
        );

    -- RS decoder
    rs_unit: entity work.rs_decoder
        port map (
            clk => rs_clk,
            reset => rs_reset,
            start => rs_start,
            codeword_in => rs_codeword,
            codeword_out => rs_corrected_codeword,
            busy => rs_busy,
            done => rs_done,
            error_detect => rs_error_detect,
            correction_valid => rs_correction_valid
        );

    stimulus: process
        variable cw : std_logic_vector(2039 downto 0);
        variable original_cw : std_logic_vector(2039 downto 0);
        variable data_vec : std_logic_vector(1911 downto 0);
        variable error_count : integer;
        variable timeout_count : integer;
    begin

        --------------------------------------------------
        -- CC TEST 1: Clean codeword
        --------------------------------------------------
        rx_bits <= CODEWORD;
        wait for 1 ns;

        assert decoded_bits = MESSAGE
            report "FAIL: clean CC codeword"
            severity error;

        if decoded_bits = MESSAGE then
            report "PASS: clean CC codeword" severity note;
        end if;

        --------------------------------------------------
        -- CC TEST 2: One-bit error
        --------------------------------------------------
        rx_bits <= CODEWORD;
        rx_bits(27) <= not CODEWORD(27);
        wait for 1 ns;

        assert decoded_bits = MESSAGE
            report "FAIL: CC one-bit error"
            severity error;

        if decoded_bits = MESSAGE then
            report "PASS: CC one-bit error" severity note;
        end if;

        --------------------------------------------------
        -- CC TEST 3: Two-bit errors
        --------------------------------------------------
        rx_bits <= CODEWORD;
        rx_bits(27) <= not CODEWORD(27);
        rx_bits(24) <= not CODEWORD(24);
        wait for 1 ns;

        assert decoded_bits = MESSAGE
            report "FAIL: CC two-bit errors"
            severity error;

        if decoded_bits = MESSAGE then
            report "PASS: CC two-bit errors" severity note;
        end if;

        report "CC tests completed" severity note;

        --------------------------------------------------
        -- Generate non-zero RS data
        --------------------------------------------------
        for i in 0 to 238 loop
            data_vec(1911 - 8*i downto 1904 - 8*i) :=
                std_logic_vector(
                    to_unsigned((i*7 + 3) mod 256, 8)
                );
        end loop;

        rs_data <= data_vec;

        --------------------------------------------------
        -- Reset encoder and decoder
        --------------------------------------------------
        rs_enc_start <= '0';
        rs_start <= '0';
        rs_reset <= '1';

        wait until falling_edge(rs_clk);
        wait until falling_edge(rs_clk);

        rs_reset <= '0';
        wait until falling_edge(rs_clk);

        --------------------------------------------------
        -- Encode non-zero message
        --------------------------------------------------
        rs_enc_start <= '1';

        wait until falling_edge(rs_clk);
        rs_enc_start <= '0';

        timeout_count := 0;

        while rs_enc_done /= '1' and timeout_count < 10 loop
            wait until rising_edge(rs_clk);
            wait for 0 ns;
            timeout_count := timeout_count + 1;
        end loop;

        assert rs_enc_done = '1'
            report "ERROR: RS encoder did not complete"
            severity failure;

        wait for 1 ns;
        original_cw := rs_encoded;

        assert original_cw /= (original_cw'range => '0')
            report "FAIL: encoder produced an all-zero codeword"
            severity error;

        report "Reference encoder completed for non-zero data"
            severity note;

        report "Encoder output captured" severity note;

        report "First encoded symbol = " &
            integer'image(
                to_integer(unsigned(original_cw(2039 downto 2032)))
            )
            severity note;

        --------------------------------------------------
        -- RS TEST 0: Clean non-zero codeword
        --------------------------------------------------
        rs_start <= '0';
        rs_reset <= '1';
        rs_codeword <= original_cw;

        wait until falling_edge(rs_clk);
        wait until falling_edge(rs_clk);

        rs_reset <= '0';
        wait until falling_edge(rs_clk);

        rs_start <= '1';
        wait until falling_edge(rs_clk);
        rs_start <= '0';

        wait until rs_done = '1';
        wait for 1 ns;

        if rs_error_detect = '0' and
           rs_correction_valid = '1' and
           rs_corrected_codeword = original_cw then

            report "PASS: clean non-zero RS codeword"
                severity note;
        else
            report "FAIL: clean non-zero RS codeword; error_detect=" &
                   std_logic'image(rs_error_detect) &
                   ", correction_valid=" &
                   std_logic'image(rs_correction_valid)
                severity error;
        end if;

        --------------------------------------------------
        -- RS TESTS: 1, 2, 4 and 8 symbol errors
        --------------------------------------------------
        for test_no in 1 to 4 loop

            case test_no is
                when 1 => error_count := 1;
                when 2 => error_count := 2;
                when 3 => error_count := 4;
                when others => error_count := 8;
            end case;

            rs_start <= '0';
            rs_reset <= '1';
            rs_codeword <= original_cw;

            wait until falling_edge(rs_clk);
            wait until falling_edge(rs_clk);

            rs_reset <= '0';
            wait until falling_edge(rs_clk);

            -- Inject symbol errors
            cw := original_cw;

            for i in 0 to error_count - 1 loop
                cw(2039 - 8*i downto 2032 - 8*i) :=
                    cw(2039 - 8*i downto 2032 - 8*i) xor
                    std_logic_vector(to_unsigned(i + 1, 8));
            end loop;

            rs_codeword <= cw;

            wait until falling_edge(rs_clk);
            rs_start <= '1';

            wait until falling_edge(rs_clk);
            rs_start <= '0';

            wait until rs_done = '1';
            wait for 1 ns;

            assert rs_error_detect = '1'
                report "FAIL: error not detected for " &
                       integer'image(error_count) & " symbol errors"
                severity error;

            assert rs_correction_valid = '1'
                report "FAIL: correction_valid for " &
                       integer'image(error_count) & " symbol errors"
                severity error;

            assert rs_corrected_codeword = original_cw
                report "FAIL: output mismatch for " &
                       integer'image(error_count) & " symbol errors"
                severity error;

            if rs_correction_valid = '1' and
               rs_corrected_codeword = original_cw then

                report "PASS: corrected " &
                       integer'image(error_count) &
                       " symbol errors in non-zero codeword"
                    severity note;
            end if;

        end loop;

        report "All CC and non-zero RS tests completed"
            severity note;

        wait;
    end process;

end architecture sim;
