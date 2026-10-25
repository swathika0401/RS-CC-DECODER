library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_viterbi_frame is
end entity tb_viterbi_frame;

architecture sim of tb_viterbi_frame is

    constant FRAME_BITS : positive := 2040;

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal start        : std_logic := '0';

    signal data_in      : std_logic := '0';
    signal encoder_valid: std_logic := '0';
    signal code_out     : std_logic_vector(1 downto 0);
    signal code_valid   : std_logic;

    signal rx_bits      : std_logic_vector(2*FRAME_BITS-1 downto 0)
                          := (others => '0');

    signal decoded_bits : std_logic_vector(FRAME_BITS-1 downto 0);
    signal busy         : std_logic;
    signal done         : std_logic;

    signal frame        : std_logic_vector(FRAME_BITS-1 downto 0)
                          := (others => '0');

begin

    clk <= not clk after 5 ns;

    encoder_inst : entity work.cc_encoder_ref
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => data_in,
            valid_in  => encoder_valid,
            code_out  => code_out,
            valid_out => code_valid
        );

    decoder_inst : entity work.viterbi_frame_decoder
        generic map (
            FRAME_BITS => FRAME_BITS
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            rx_bits      => rx_bits,
            decoded_bits => decoded_bits,
            busy         => busy,
            done         => done
        );

    stimulus : process
        variable encoded_count : integer := 0;
    begin

        report "TEST START" severity note;

        reset <= '1';
        encoder_valid <= '0';

        wait for 30 ns;
        wait until falling_edge(clk);
        reset <= '0';

        -- Generate deterministic frame
        for i in 0 to FRAME_BITS-1 loop
            if (i mod 7 = 0) or (i mod 11 = 0) then
                frame(FRAME_BITS-1-i) <= '1';
            else
                frame(FRAME_BITS-1-i) <= '0';
            end if;
        end loop;

        wait until falling_edge(clk);

        -- Enable encoder for exactly FRAME_BITS input bits
        encoded_count := 0;
        encoder_valid <= '1';

        for i in 0 to FRAME_BITS-1 loop

            data_in <= frame(FRAME_BITS-1-i);

            wait until rising_edge(clk);
            wait for 1 ns;

            if code_valid = '1' then
                rx_bits(
                    2*FRAME_BITS-1-2*encoded_count downto
                    2*FRAME_BITS-2-2*encoded_count
                ) <= code_out;

                encoded_count := encoded_count + 1;
            end if;

        end loop;

        encoder_valid <= '0';
        data_in <= '0';

        assert encoded_count = FRAME_BITS
            report "FAIL: incorrect encoded bit count"
            severity failure;

        report "Encoder completed; starting decoder"
            severity note;

        wait until falling_edge(clk);
        start <= '1';

        wait until falling_edge(clk);
        start <= '0';

        -- Prevent the test from hanging indefinitely
        wait until done = '1' for 100 us;

        if done /= '1' then
            assert false
                report "FAIL: Viterbi decoder timed out"
                severity failure;
        end if;

        wait for 1 ns;

        assert decoded_bits = frame
            report "FAIL: decoded frame differs from input"
            severity failure;

        report "PASS: original frame recovered successfully"
            severity note;

        wait;
    end process;

end architecture sim;
