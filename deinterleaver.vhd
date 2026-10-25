library ieee;
use ieee.std_logic_1164.all;

entity deinterleaver is
    port (
        data_in  : in  std_logic_vector(2039 downto 0);
        data_out : out std_logic_vector(2039 downto 0)
    );
end entity;

architecture rtl of deinterleaver is
begin
    process(data_in)
        variable temp : std_logic_vector(2039 downto 0);
        variable dst  : integer;
    begin
        for r in 0 to 254 loop
            for c in 0 to 7 loop
                dst := 2039 - (r * 8 + c);
                temp(dst) := data_in(2039 - (c * 255 + r));
            end loop;
        end loop;

        data_out <= temp;
    end process;
end architecture;
