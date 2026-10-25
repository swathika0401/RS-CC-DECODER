library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tx_chain is
end entity;

architecture sim of tb_tx_chain is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal start     : std_logic := '0';

    signal data_in   : std_logic_vector(1911 downto 0)
                       := (others => '0');
    signal rs_word   : std_logic_vector(2039 downto 0)
                       := (others => '0');
    signal mixed     : std_logic_vector(2039 downto 0);
    signal recovered : std_logic_vector(2039 downto 0);

    signal busy      : std_logic;
    signal done      : std_logic;
begin

    clk <= not clk after 5 ns;

    -- RS encoder
    rs_enc: entity work.rs_reference_encoder
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            data_in      => data_in,
            codeword_out => rs_word,
            busy         => busy,
            done         => done
        );

    -- Interleaver
    intlv: entity work.interleaver
        port map (
            data_in  => rs_word,
            data_out => mixed
        );

    -- Deinterleaver
    deintlv: entity work.deinterleaver
        port map (
            data_in  => mixed,
            data_out => recovered
        );

    stimulus: process
    begin
        report "Starting RS/interleaver chain test"
            severity note;

        -- Generate deterministic, non-zero input data
        for i in 0 to 238 loop
            data_in(1911 - 8*i downto 1904 - 8*i) <=
                std_logic_vector(
                    to_unsigned((i*7 + 3) mod 256, 8)
                );
        end loop;

        -- Allow input data to settle
        wait for 1 ns;

        -- Reset encoder
        reset <= '1';
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        reset <= '0';

   -- Start encoding on a rising clock edge
wait until rising_edge(clk);
start <= '1';

wait until rising_edge(clk);
start <= '0';

report "DEBUG: start pulse sent" severity note;

-- Wait for completion, with timeout
wait until done = '1' for 1 us;

report "DEBUG: done=" & std_logic'image(done)
    severity note;

report "DEBUG: busy=" & std_logic'image(busy)
    severity note;

        if done /= '1' then
            assert false
                report "FAIL: RS encoder completion timeout"
                severity failure;
        end if;

        -- Allow output signals to settle
        wait for 1 ns;

        assert rs_word /= (rs_word'range => '0')
            report "FAIL: RS encoder output is zero"
            severity failure;

        assert recovered = rs_word
            report "FAIL: interleaver/deinterleaver changed RS codeword"
            severity failure;

        report "PASS: RS encoder + interleaver + deinterleaver"
            severity note;

        wait;
    end process;

end architecture;
