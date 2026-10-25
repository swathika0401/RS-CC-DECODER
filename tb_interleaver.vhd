library ieee;
use ieee.std_logic_1164.all;


entity tb_interleaver is
end entity;

architecture sim of tb_interleaver is
    signal original_data : std_logic_vector(2039 downto 0);
    signal interleaved_data : std_logic_vector(2039 downto 0);
    signal recovered_data : std_logic_vector(2039 downto 0);
begin

    enc_inst : entity work.interleaver
        port map (
            data_in  => original_data,
            data_out => interleaved_data
        );

    dec_inst : entity work.deinterleaver
        port map (
            data_in  => interleaved_data,
            data_out => recovered_data
        );

    process
    begin
        original_data <= (others => '0');
        wait for 10 ns;

        assert recovered_data = original_data
            report "FAIL: all-zero round trip"
            severity failure;

        original_data <= (others => '1');
        wait for 10 ns;

        assert recovered_data = original_data
            report "FAIL: all-one round trip"
            severity failure;

        original_data <= (others => '0');
        original_data(2039) <= '1';
        original_data(1000) <= '1';
        original_data(0) <= '1';
        wait for 10 ns;

        assert recovered_data = original_data
            report "FAIL: bit-pattern round trip"
            severity failure;

        report "PASS: interleaver/deinterleaver round trip" severity note;
        
        wait;
    end process;

end architecture;
