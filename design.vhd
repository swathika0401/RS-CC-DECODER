
library ieee;
use ieee.std_logic_1164.all;

entity cc_encoder_ref is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        data_in   : in  std_logic;i s
        valid_in  : in  std_logic;
        code_out  : out std_logic_vector(1 downto 0);
        valid_out : out std_logic
    );
end entity cc_encoder_ref;

architecture behavioral of cc_encoder_ref is
    signal shift_reg : std_logic_vector(6 downto 0)
                       := (others => '0');
begin

    process(clk)
        variable reg_next : std_logic_vector(6 downto 0);
        variable c1       : std_logic;
        variable c2       : std_logic;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                shift_reg <= (others => '0');
                code_out  <= (others => '0');
                valid_out <= '0';

            else
                valid_out <= '0';

                if valid_in = '1' then
                    reg_next := data_in & shift_reg(6 downto 1);

                    c1 := reg_next(6) xor reg_next(5) xor
                          reg_next(4) xor reg_next(3) xor
                          reg_next(0);

                    c2 := not (
                          reg_next(6) xor reg_next(4) xor
                          reg_next(3) xor reg_next(1) xor
                          reg_next(0)
                          );

                    shift_reg <= reg_next;
                    code_out  <= c1 & c2;
                    valid_out <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;

