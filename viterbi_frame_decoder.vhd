
library ieee;
use ieee.std_logic_1164.all;

entity viterbi_frame_decoder is
    generic (
        FRAME_BITS : positive := 20;
        TERMINATED : boolean := true
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;
        rx_bits      : in  std_logic_vector(2*FRAME_BITS-1 downto 0);
        decoded_bits : out std_logic_vector(FRAME_BITS-1 downto 0);
        busy         : out std_logic;
        done         : out std_logic
    );
end entity viterbi_frame_decoder;

architecture rtl of viterbi_frame_decoder is

    signal core_decoded : std_logic_vector(FRAME_BITS-1 downto 0);

    signal rx_latched : std_logic_vector(2*FRAME_BITS-1 downto 0)
                        := (others => '0');

    type state_type is (IDLE, WAIT_RESULT, COMPLETE);
    signal state : state_type := IDLE;

begin

    core_inst : entity work.viterbi_decoder
        generic map (
            DATA_BITS  => FRAME_BITS,
            TERMINATED => TERMINATED
        )
        port map (
            rx_bits      => rx_latched,
            decoded_bits => core_decoded
        );

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                state        <= IDLE;
                rx_latched   <= (others => '0');
                decoded_bits <= (others => '0');
                busy         <= '0';
                done         <= '0';

            else
                done <= '0';

                case state is

                    when IDLE =>
                        busy <= '0';

                        if start = '1' then
                            rx_latched <= rx_bits;
                            busy       <= '1';
                            state      <= WAIT_RESULT;
                        end if;

                    when WAIT_RESULT =>
                        -- Preserve every decoded frame bit.
                       if TERMINATED then
    decoded_bits <= "000000" & core_decoded(FRAME_BITS-1 downto 6);
else
    decoded_bits <= core_decoded;
end if;
                        state        <= COMPLETE;

                    when COMPLETE =>
                        busy  <= '0';
                        done  <= '1';
                        state <= IDLE;

                end case;
            end if;

        end if;
    end process;

end architecture rtl;

