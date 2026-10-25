library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_cc_viterbi is
end entity tb_cc_viterbi;

architecture sim of tb_cc_viterbi is

    constant DATA_BITS : positive := 14;
    constant STEPS     : positive := DATA_BITS + 6;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal data_in   : std_logic := '0';
    signal valid_in  : std_logic := '0';

    signal code_out  : std_logic_vector(1 downto 0);
    signal valid_out : std_logic;

    signal rx_bits : std_logic_vector(2*STEPS-1 downto 0)
                     := (others => '0');

    signal decoded : std_logic_vector(STEPS-1 downto 0)
                     := (others => '0');

    signal dec_start : std_logic := '0';
    signal dec_busy  : std_logic;
    signal dec_done  : std_logic;

    constant MESSAGE : std_logic_vector(DATA_BITS-1 downto 0)
                       := "10110010000000";

    function bits_to_string(
        v : std_logic_vector
    ) return string is
        variable s : string(1 to v'length);
        variable k : integer := 1;
    begin
        for i in v'range loop
            if v(i) = '0' then
                s(k) := '0';
            elsif v(i) = '1' then
                s(k) := '1';
            else
                s(k) := 'X';
            end if;
            k := k + 1;
        end loop;
        return s;
    end function;

begin

    clk <= not clk after 5 ns;

    enc: entity work.cc_encoder_ref
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => data_in,
            valid_in  => valid_in,
            code_out  => code_out,
            valid_out => valid_out
        );

    dec: entity work.viterbi_frame_decoder
        generic map (
            FRAME_BITS => STEPS
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

    stimulus: process
        variable frame   : std_logic_vector(STEPS-1 downto 0);
        variable encoded : std_logic_vector(2*STEPS-1 downto 0);
    begin

        report "Starting CC + Viterbi single-bit error test"
            severity note;

        frame := MESSAGE & "000000";

        wait for 20 ns;
        wait until falling_edge(clk);
        reset <= '0';

        -- Encode message and six zero tail bits
        for i in 0 to STEPS-1 loop
            data_in  <= frame(STEPS-1-i);
            valid_in <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;

            assert valid_out = '1'
                report "FAIL: encoder valid_out was not asserted"
                severity failure;

            encoded(2*STEPS-1-2*i downto
                    2*STEPS-2-2*i) := code_out;

            wait until falling_edge(clk);
        end loop;

        valid_in <= '0';

        -- Inject one channel-bit error
        encoded(10) := not encoded(10);

        report "Single-bit channel error injected"
            severity note;

        -- Supply the corrupted encoded frame
        rx_bits <= encoded;

        wait until falling_edge(clk);
        dec_start <= '1';

        wait until falling_edge(clk);
        dec_start <= '0';

        -- Wait until Viterbi decoding is complete
        wait until dec_done = '1';
        wait for 1 ns;

        report "Expected: " & bits_to_string(MESSAGE)
            severity note;

        report "Decoded : " &
            bits_to_string(decoded(STEPS-1 downto 6))
            severity note;

        assert decoded(STEPS-1 downto 6) = MESSAGE
            report "FAIL: decoded message differs from original"
            severity failure;

        assert decoded(5 downto 0) = "000000"
            report "FAIL: tail bits were not recovered"
            severity failure;

        report "PASS: CC encoder + Viterbi decoder recovered message after one-bit error"
            severity note;

        stop;
        wait;
    end process;

end architecture sim;
