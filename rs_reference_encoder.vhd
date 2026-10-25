library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Reference systematic CCSDS RS(255,239) encoder.
-- Input and output symbols use the dual-basis byte representation used by rs_decoder.
-- Data symbols are ordered first; 16 parity symbols are appended.
entity rs_reference_encoder is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;
        data_in      : in  std_logic_vector(1911 downto 0); -- 239 x 8 bits
        codeword_out : out std_logic_vector(2039 downto 0); -- 255 x 8 bits
        busy         : out std_logic;
        done         : out std_logic
    );
end entity;

architecture rtl of rs_reference_encoder is
    type symbol_array is array (natural range <>) of std_logic_vector(7 downto 0);
    subtype data_array is symbol_array(0 to 238);
    subtype code_array is symbol_array(0 to 254);
    subtype parity_array is symbol_array(0 to 15);
    subtype gen_array is symbol_array(0 to 16);

    function gf_mult(a, b : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable x : unsigned(7 downto 0) := unsigned(a);
        variable y : unsigned(7 downto 0) := unsigned(b);
        variable r : unsigned(7 downto 0) := (others => '0');
    begin
        for i in 0 to 7 loop
            if y(0) = '1' then r := r xor x; end if;
            if x(7) = '1' then
                x := shift_left(x, 1) xor to_unsigned(16#87#, 8);
            else
                x := shift_left(x, 1);
            end if;
            y := shift_right(y, 1);
        end loop;
        return std_logic_vector(r);
    end function;

    function gf_pow_alpha(n : integer) return std_logic_vector is
        variable v : std_logic_vector(7 downto 0) := x"01";
        variable e : integer := n mod 255;
    begin
        for i in 1 to e loop v := gf_mult(v, x"02"); end loop;
        return v;
    end function;

    -- Same dual-basis -> polynomial-basis map as the supplied decoder.
    function dual_to_poly(z : std_logic_vector(7 downto 0)) return std_logic_vector is
        type matrix_type is array (0 to 7) of std_logic_vector(7 downto 0);
        constant M : matrix_type := (
            "11000101", "01000010", "00101110", "11111101",
            "11110000", "01111001", "10101100", "11001100");
        variable u : std_logic_vector(7 downto 0);
        variable p : std_logic;
    begin
        for j in 0 to 7 loop
            p := '0';
            for i in 0 to 7 loop
                if z(7-i) = '1' and M(i)(7-j) = '1' then p := not p; end if;
            end loop;
            u(7-j) := p;
        end loop;
        return u;
    end function;

    -- Same polynomial-basis -> dual-basis map as the supplied decoder.
    function poly_to_dual(u : std_logic_vector(7 downto 0)) return std_logic_vector is
        type matrix_type is array (0 to 7) of std_logic_vector(7 downto 0);
        constant MI : matrix_type := (
            "11111110", "01101001", "01101011", "00001101",
            "11101111", "11110010", "01011011", "11000111");
        variable z : std_logic_vector(7 downto 0);
        variable p : std_logic;
    begin
        for i in 0 to 7 loop
            p := '0';
            for k in 0 to 7 loop
                if u(7-k) = '1' and MI(i)(7-k) = '1' then p := not p; end if;
            end loop;
            z(7-i) := p;
        end loop;
        return z;
    end function;

    -- Generator g(x)=product(x + alpha^(11*j)), j=120..135.
    -- Coefficients are stored in ascending powers: g(0) is the constant term.
    function make_generator return gen_array is
        variable g : gen_array := (others => x"00");
        variable ng : gen_array;
        variable root : std_logic_vector(7 downto 0);
    begin
        g(0) := x"01";
        for j in 120 to 135 loop
            root := gf_pow_alpha((11*j) mod 255);
            ng := (others => x"00");
            for k in 0 to 16 loop
                if g(k) /= x"00" then
                    ng(k) := ng(k) xor gf_mult(g(k), root);
                    if k < 16 then ng(k+1) := ng(k+1) xor g(k); end if;
                end if;
            end loop;
            g := ng;
        end loop;
        return g;
    end function;

    constant GENERATOR : gen_array := make_generator;

    function encode(data : data_array) return code_array is
        variable result_word : code_array := (others => x"00");
        variable parity : parity_array := (others => x"00");
        variable feedback : std_logic_vector(7 downto 0);
    begin
        for i in 0 to 238 loop
            result_word(i) := data(i);
            feedback := data(i) xor parity(0);
            for k in 0 to 14 loop
                parity(k) := parity(k+1) xor gf_mult(feedback, GENERATOR(15-k));
            end loop;
            parity(15) := gf_mult(feedback, GENERATOR(0));
        end loop;
        for i in 0 to 15 loop result_word(239+i) := parity(i); end loop;
        return result_word;
    end function;

    signal busy_i : std_logic := '0';
    signal done_i : std_logic := '0';
begin
    busy <= busy_i;
    done <= done_i;

    process(clk)
        variable data_poly : data_array;
        variable encoded_poly : code_array;
        variable output_word : std_logic_vector(2039 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                busy_i <= '0';
                done_i <= '0';
                codeword_out <= (others => '0');
            else
                done_i <= '0';
                if start = '1' and busy_i = '0' then
                    busy_i <= '1';
                    for i in 0 to 238 loop
                        data_poly(i) := dual_to_poly(data_in(1911-8*i downto 1904-8*i));
                    end loop;
                    encoded_poly := encode(data_poly);
                    output_word := (others => '0');
                    for i in 0 to 254 loop
                        output_word(2039-8*i downto 2032-8*i) := poly_to_dual(encoded_poly(i));
                    end loop;
                    codeword_out <= output_word;
                    busy_i <= '0';
                    done_i <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture;
