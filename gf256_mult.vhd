library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gf256_mult is
    port (
        a      : in  std_logic_vector(7 downto 0);
        b      : in  std_logic_vector(7 downto 0);
        result : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of gf256_mult is
begin
    process(a, b)
        variable x   : unsigned(7 downto 0);
        variable y   : unsigned(7 downto 0);
        variable res : unsigned(7 downto 0);
    begin
        x := unsigned(a);
        y := unsigned(b);
        res := (others => '0');

        for i in 0 to 7 loop
            if y(0) = '1' then
                res := res xor x;
            end if;

            if x(7) = '1' then
                x := shift_left(x, 1) xor to_unsigned(16#87#, 8);
            else
                x := shift_left(x, 1);
            end if;

            y := shift_right(y, 1);
        end loop;

        result <= std_logic_vector(res);
    end process;
end architecture;
