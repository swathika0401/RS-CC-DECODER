library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_chain is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        start   : in  std_logic;
        data_in : in  std_logic_vector(1911 downto 0);
        tx_bits : out std_logic_vector(4079 downto 0);
        busy    : out std_logic;
        done    : out std_logic
    );
end entity tx_chain;

architecture rtl of tx_chain is

    signal rs_codeword : std_logic_vector(2039 downto 0);
    signal interleaved : std_logic_vector(2039 downto 0);

    signal rs_busy : std_logic;
    signal rs_done : std_logic;

    signal cc_data      : std_logic := '0';
    signal cc_valid     : std_logic := '0';
    signal cc_code      : std_logic_vector(1 downto 0);
    signal cc_valid_out : std_logic;

    signal tx_reg : std_logic_vector(4079 downto 0)
                   := (others => '0');

    signal bit_index : integer range 0 to 2040 := 0;
    signal cc_count  : integer range 0 to 2040 := 0;

    signal active   : std_logic := '0';
    signal finished : std_logic := '0';
    signal rs_seen  : std_logic := '0';

begin

    rs_inst : entity work.rs_reference_encoder
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            data_in      => data_in,
            codeword_out => rs_codeword,
            busy         => rs_busy,
            done         => rs_done
        );

    int_inst : entity work.interleaver
        port map (
            data_in  => rs_codeword,
            data_out => interleaved
        );

    cc_inst : entity work.cc_encoder_ref
        port map (
            clk       => clk,
            reset     => reset,
            data_in   => cc_data,
            valid_in  => cc_valid,
            code_out  => cc_code,
            valid_out => cc_valid_out
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                bit_index <= 0;
                cc_count  <= 0;
                active    <= '0';
                finished  <= '0';
                rs_seen   <= '0';
                cc_data   <= '0';
                cc_valid  <= '0';
                tx_reg    <= (others => '0');

            else
                finished <= '0';
                cc_valid <= '0';

                -- Remember RS encoder completion
                if rs_done = '1' then
                    rs_seen <= '1';
                end if;

                -- Begin serialization after RS encoding completes
                if rs_seen = '1' and active = '0'
                   and bit_index = 0 and cc_count = 0 then
                    active <= '1';

                elsif active = '1' and bit_index < 2040 then
                    cc_data   <= interleaved(2039 - bit_index);
                    cc_valid  <= '1';
                    bit_index <= bit_index + 1;
                end if;

                -- Capture registered CC output pairs
                if cc_valid_out = '1' and cc_count < 2040 then
                    tx_reg(4079 - 2*cc_count downto
                           4078 - 2*cc_count) <= cc_code;

                    cc_count <= cc_count + 1;

                    if cc_count = 2039 then
                        active   <= '0';
                        finished <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    tx_bits <= tx_reg;
    busy    <= rs_busy or active;
    done    <= finished;

end architecture rtl;
