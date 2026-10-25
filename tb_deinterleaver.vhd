library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_deinterleaver is
end entity;

architecture sim of tb_deinterleaver is
    signal data_in  : std_logic_vector(16319 downto 0)
                     := (others => '0');
    signal data_out : std_logic_vector(16319 downto 0);
begin
    dut : entity work.deinterleaver
        port map (
            data_in  => data_in,
            data_out => data_out
        );

    process
        variable original : std_logic_vector(16319 downto 0);
        variable interleaved : std_logic_vector(16319 downto 0);
    begin
        -- Create eight distinguishable codewords.
        for c in 0 to 7 loop
            for r in 0 to 254 loop
                for b in 0 to 7 loop
                    original(16319 - (c*2040 + r*8 + b)) :=
                        std_logic'val(2 + ((c + r + b) mod 2));
                end loop;
            end loop;
        end loop;

        -- Interleave symbols round-robin.
        for r in 0 to 254 loop
            for c in 0 to 7 loop
                for b in 0 to 7 loop
                    interleaved(16319 - ((r*8 + c)*8 + b)) :=
                        original(16319 - (c*2040 + r*8 + b));
                end loop;
            end loop;
        end loop;

        data_in <= interleaved;
        wait for 10 ns;

        assert data_out = original
            report "FAIL: deinterleaving mismatch"
            severity failure;

        report "PASS: depth-8 deinterleaving round trip"
            severity note;

        wait;
    end process;
end architecture;
