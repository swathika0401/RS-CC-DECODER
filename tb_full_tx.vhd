library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_full_tx is
end entity;

architecture sim of tb_full_tx is

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';

    signal data_in  : std_logic_vector(1911 downto 0)
                      := (others => '0');

    signal tx_bits  : std_logic_vector(4079 downto 0);
    signal busy     : std_logic;
    signal done     : std_logic;

    -- Independent reference path
    signal ref_rs_word : std_logic_vector(2039 downto 0);
    signal ref_mixed   : std_logic_vector(2039 downto 0);

    signal ref_rs_busy : std_logic;
    signal ref_rs_done : std_logic;

    signal ref_data  : std_logic := '0';
    signal ref_valid : std_logic := '0';
    signal ref_code  : std_logic_vector(1 downto 0);
    signal ref_valid_out : std_logic;

    signal ref_bits : std_logic_vector(4079 downto 0)
                      := (others => '0');

    signal ref_index : integer range 0 to 2040 := 0;
    signal ref_count : integer range 0 to 2040 := 0;
    signal ref_active : std_logic := '0';
    signal ref_complete : std_logic := '0';

begin

    clk <= not clk after 5 ns;

    -- Transmitter under test
    dut : entity work.tx_chain
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            data_in => data_in,
            tx_bits => tx_bits,
            busy    => busy,
            done    => done
        );

    -- Reference RS encoder
    ref_rs : entity work.rs_reference_encoder
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            data_in      => data_in,
            codeword_out => ref_rs_word,
            busy         => ref_rs_busy,
            done         => ref_rs_done
        );

    -- Reference interleaver
    ref_int : entity work.interleaver
        port map (
            data_in  => ref_rs_word,
            data_out => ref_mixed
        );

    -- Reference CC encoder
    ref_cc : entity work.cc_encoder_ref
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => ref_data,
            valid_in  => ref_valid,
            code_out  => ref_code,
            valid_out => ref_valid_out
        );

    -- Reference serializer and output capture
    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                ref_data     <= '0';
                ref_valid    <= '0';
                ref_index    <= 0;
                ref_count    <= 0;
                ref_active   <= '0';
                ref_complete <= '0';
                ref_bits     <= (others => '0');

            else
                ref_valid    <= '0';
                ref_complete <= '0';

                if ref_rs_done = '1' and ref_active = '0'
                   and ref_index = 0 and ref_count = 0 then
                    ref_active <= '1';

                elsif ref_active = '1'
                      and ref_index < 2040 then
                    ref_data  <= ref_mixed(2039 - ref_index);
                    ref_valid <= '1';
                    ref_index <= ref_index + 1;
                end if;

                if ref_valid_out = '1' and ref_count < 2040 then
                    ref_bits(4079 - 2*ref_count downto
                             4078 - 2*ref_count) <= ref_code;

                    ref_count <= ref_count + 1;

                    if ref_count = 2039 then
                        ref_active   <= '0';
                        ref_complete <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Test stimulus
    stimulus : process
    begin
        report "Starting transmitter reference comparison"
            severity note;

        for i in 0 to 238 loop
            data_in(1911 - 8*i downto 1904 - 8*i) <=
                std_logic_vector(to_unsigned((i*7 + 3) mod 256, 8));
        end loop;

        wait for 1 ns;
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        reset <= '0';

        wait until falling_edge(clk);
        start <= '1';

        wait until falling_edge(clk);
        start <= '0';

        -- Wait for both paths to finish.
        -- Their completion pulses may occur simultaneously.
        wait for 25 us;

        report "DEBUG: reference count = " &
               integer'image(ref_count)
               severity note;

        assert ref_count = 2040
            report "FAIL: reference did not capture 2040 pairs"
            severity failure;

        assert busy = '0'
            report "FAIL: transmitter still busy"
            severity failure;

        assert tx_bits /= (tx_bits'range => '0')
            report "FAIL: transmitter output is all zero"
            severity failure;

        assert tx_bits = ref_bits
            report "FAIL: transmitter output differs from reference"
            severity failure;

        report "PASS: transmitter output matches reference"
            severity note;

        wait;

    end process;

end architecture;
