
library ieee;
use ieee.std_logic_1164.all;

entity tb_cc_viterbi_ise is
end entity tb_cc_viterbi_ise;

architecture sim of tb_cc_viterbi_ise is
    constant DATA_BITS  : positive := 14;
    constant FRAME_BITS : positive := DATA_BITS + 6;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal data_in   : std_logic := '0';
    signal valid_in  : std_logic := '0';

    signal code_out  : std_logic_vector(1 downto 0);
    signal valid_out : std_logic;

    signal rx_bits : std_logic_vector(2*FRAME_BITS-1 downto 0)
                     := (others => '0');

    signal decoded   : std_logic_vector(FRAME_BITS-1 downto 0);
    signal dec_start : std_logic := '0';
    signal dec_busy  : std_logic;
    signal dec_done  : std_logic;

    constant MESSAGE : std_logic_vector(DATA_BITS-1 downto 0)
                       := "10110010000000";

begin
    clock_process : process
    begin
        for i in 0 to 99 loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    enc : entity work.cc_encoder_ref
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => data_in,
            valid_in  => valid_in,
            code_out  => code_out,
            valid_out => valid_out
        );

    dec : entity work.viterbi_frame_decoder
        generic map (
            FRAME_BITS => FRAME_BITS
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => dec_start,
            rx_bits      => rx_bits,
            decoded_bits => decoded,
            busy         => dec_busy,
            done         => dec_done
        );

    stimulus : process
        variable frame   : std_logic_vector(FRAME_BITS-1 downto 0);
        variable encoded : std_logic_vector(2*FRAME_BITS-1 downto 0);
    begin
        frame := MESSAGE & "000000";

        wait for 20 ns;
        wait until falling_edge(clk);
        reset <= '0';

        -- Encode the message and six terminating zero bits.
        for i in 0 to FRAME_BITS-1 loop
            data_in  <= frame(FRAME_BITS-1-i);
            valid_in <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;

            assert valid_out = '1'
                report "FAIL: encoder valid_out was not asserted"
                severity failure;

            encoded(2*FRAME_BITS-1-2*i downto
                    2*FRAME_BITS-2-2*i) := code_out;

            wait until falling_edge(clk);
        end loop;

        valid_in <= '0';

        -- Inject one channel-bit error.
        encoded(10) := not encoded(10);
        rx_bits <= encoded;

        wait until falling_edge(clk);
        dec_start <= '1';

        wait until falling_edge(clk);
        dec_start <= '0';

        -- Timeout prevents an indefinite wait for decoder completion.
        wait until dec_done = '1' for 1 us;

        if dec_done /= '1' then
            assert false
                report "FAIL: Viterbi decoder timed out"
                severity failure;
            wait;
        end if;

        wait for 1 ns;

        -- TEMPORARY DIAGNOSTIC REPORTS
        report "Expected frame = " & to_string(frame)
            severity note;

        report "Decoded frame  = " & to_string(decoded)
            severity note;

        assert decoded(DATA_BITS-1 downto 0) = MESSAGE
            report "FAIL: decoded message differs from original"
            severity failure;

        assert decoded(FRAME_BITS-1 downto DATA_BITS) = "000000"
            report "FAIL: terminating tail bits are not zero"
            severity failure;

        report "PASS: CC encoder + Viterbi decoder recovered message after one-bit error"
            severity note;

        wait;
    end process;
end architecture sim;

