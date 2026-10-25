library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rs8_encoder is
end entity;

architecture sim of tb_rs8_encoder is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal data_in : std_logic_vector(1911 downto 0)
                     := (others => '0');
    signal codeword_out : std_logic_vector(2039 downto 0);
    signal busy : std_logic;
    signal done : std_logic;

    type frame_array is array (0 to 7) of
        std_logic_vector(2039 downto 0);
    signal frame : frame_array;

begin
    clk <= not clk after 5 ns;

    dut : entity work.rs_reference_encoder
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            data_in      => data_in,
            codeword_out => codeword_out,
            busy         => busy,
            done         => done
        );

    stimulus : process
        variable d : std_logic_vector(1911 downto 0);
    begin
        wait for 20 ns;
        wait until rising_edge(clk);
        reset <= '0';

        for n in 0 to 7 loop
            for i in 0 to 238 loop
                d(1911-8*i downto 1904-8*i) :=
                    std_logic_vector(to_unsigned((n*31+i*7+3) mod 256, 8));
            end loop;

            data_in <= d;
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';

            wait until done = '1';
            frame(n) <= codeword_out;
            wait until rising_edge(clk);
        end loop;

        report "PASS: generated eight RS codewords"
            severity note;
        wait;
    end process;
end architecture;
