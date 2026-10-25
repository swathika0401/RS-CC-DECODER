library ieee;
use ieee.std_logic_1164.all;

entity interleaver is
    port (
        data_in  : in  std_logic_vector(2039 downto 0);
        data_out : out std_logic_vector(2039 downto 0)
    );
end entity;

architecture rtl of interleaver is
begin
    process(data_in)
        variable temp : std_logic_vector(2039 downto 0);
        variable src  : integer;
    begin
        for r in 0 to 254 loop
            for c in 0 to 7 loop
                src := 2039 - (r * 8 + c);
                temp(2039 - (c * 255 + r)) := data_in(src);
            end loop;
        end loop;

        data_out <= temp;
    end process;
end architecture;
