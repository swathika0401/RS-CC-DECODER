
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i8_interleave is
end entity;

architecture sim of tb_i8_interleave is
    signal original      : std_logic_vector(16319 downto 0);
    signal interleaved   : std_logic_vector(16319 downto 0);
    signal deinterleaved : std_logic_vector(16319 downto 0);
begin

    enc : entity work.interleaver_i8
        port map (
            data_in  => original,
            data_out => interleaved
        );

    dec : entity work.deinterleaver_i8
        port map (
            data_in  => interleaved,
            data_out => deinterleaved
        );

    process
        variable pattern : std_logic_vector(16319 downto 0);
    begin
        for i in 0 to 16319 loop
            pattern(i) := '0';
            if (i mod 3) = 0 then
                pattern(i) := '1';
            end if;
        end loop;

        original <= pattern;
        wait for 10 ns;

        assert deinterleaved = pattern
            report "FAIL: depth-8 interleaver round trip"
            severity failure;

        report "PASS: depth-8 interleaver and deinterleaver round trip"
            severity note;

        wait;
    end process;

end architecture;

