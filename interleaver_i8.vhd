
library ieee;
use ieee.std_logic_1164.all;

entity interleaver_i8 is
    port (
        data_in  : in  std_logic_vector(16319 downto 0);
        data_out : out std_logic_vector(16319 downto 0)
    );
end entity interleaver_i8;

architecture rtl of interleaver_i8 is
begin
    process(data_in)
        variable temp : std_logic_vector(16319 downto 0);
        variable src  : integer;
        variable dst  : integer;
    begin
        for r in 0 to 254 loop
            for c in 0 to 7 loop
                for b in 0 to 7 loop
                    src := 16319 - (c * 2040 + r * 8 + b);
                    dst := 16319 - ((r * 8 + c) * 8 + b);

                    temp(dst) := data_in(src);
                end loop;
            end loop;
        end loop;

        data_out <= temp;
    end process;
end architecture rtl;
