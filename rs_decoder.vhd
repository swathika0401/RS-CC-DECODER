library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rs_decoder is
    port (
        clk              : in  std_logic;
        reset            : in  std_logic;
        start            : in  std_logic;
        codeword_in      : in  std_logic_vector(2039 downto 0);
        codeword_out     : out std_logic_vector(2039 downto 0);
        busy             : out std_logic;
        done             : out std_logic;
        error_detect     : out std_logic;
        correction_valid : out std_logic
    );
end entity rs_decoder;

architecture rtl of rs_decoder is
    type state_type is (IDLE, CALCULATE, CHECK);
    signal state : state_type := IDLE;

    type symbol_array is array (0 to 254) of std_logic_vector(7 downto 0);
    type syndrome_array is array (0 to 15) of std_logic_vector(7 downto 0);
    type locator_array is array (0 to 16) of std_logic_vector(7 downto 0);
    type position_array is array (0 to 7) of integer range 0 to 254;
    type field_array is array (0 to 7) of std_logic_vector(7 downto 0);
    type matrix_row is array (0 to 8) of std_logic_vector(7 downto 0);
    type matrix_array is array (0 to 7) of matrix_row;

    type decode_result is record
        corrected : symbol_array;
        valid     : std_logic;
        has_error : std_logic;
    end record;

    signal symbols : symbol_array := (others => (others => '0'));
    signal syndromes : syndrome_array := (others => (others => '0'));
    signal index : integer range 0 to 15 := 0;
    signal bad : std_logic := '0';

    -- GF(256), F(x)=x^8+x^7+x^2+x+1; reduction constant is 0x87.
    function gf_mult(a, b : std_logic_vector(7 downto 0))
        return std_logic_vector is
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
    begin
        for i in 1 to n loop v := gf_mult(v, x"02"); end loop;
        return v;
    end function;

    function gf_inverse(a : std_logic_vector(7 downto 0))
        return std_logic_vector is
        variable v : std_logic_vector(7 downto 0) := x"01";
    begin
        if a = x"00" then return x"00"; end if;
        for i in 1 to 254 loop v := gf_mult(v, a); end loop;
        return v;
    end function;

    function gf_div(a, b : std_logic_vector(7 downto 0))
        return std_logic_vector is
    begin
        if b = x"00" then return x"00"; end if;
        return gf_mult(a, gf_inverse(b));
    end function;

    -- CCSDS dual-basis to polynomial-basis conversion matrix.
    function dual_to_poly(z : std_logic_vector(7 downto 0))
        return std_logic_vector is
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

    -- Inverse of the conversion matrix above.
    function poly_to_dual(u : std_logic_vector(7 downto 0))
        return std_logic_vector is
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

    function calc_syndrome(syms : symbol_array; root_index : integer)
        return std_logic_vector is
        variable s : std_logic_vector(7 downto 0) := (others => '0');
        variable e : integer;
        variable a : std_logic_vector(7 downto 0);
    begin
        for j in 0 to 254 loop
            e := ((254-j) * (11*(120+root_index))) mod 255;
            a := gf_pow_alpha(e);
            s := s xor gf_mult(syms(j), a);
        end loop;
        return s;
    end function;

    -- Complete algebraic RS decoder: Berlekamp-Massey, Chien search,
    -- syndrome-equation solve for magnitudes, correction and recheck.
    function decode_rs(input_symbols : symbol_array; input_syndromes : syndrome_array)
        return decode_result is
        variable outv : decode_result;
        variable c, bpoly, oldc : locator_array;
        variable l : integer range 0 to 16 := 0;
        variable m : integer range 1 to 17 := 1;
        variable d, scale, bprev : std_logic_vector(7 downto 0);
        variable pos : position_array;
        variable xpos : field_array;
        variable found : integer range 0 to 255 := 0;
        variable z, xval, evalv, power : std_logic_vector(7 downto 0);
        variable mat : matrix_array;
        variable tmp : std_logic_vector(7 downto 0);
        variable pivot : integer;
        variable pivot_found : boolean;
        variable mag : field_array;
        variable ok : boolean := true;
        variable corrected_tmp : symbol_array;
    begin
        outv.corrected := input_symbols;
        outv.valid := '0';
        outv.has_error := '0';

        for n in 0 to 15 loop
            if input_syndromes(n) /= x"00" then outv.has_error := '1'; end if;
        end loop;

        -- Berlekamp-Massey on the 16 consecutive CCSDS syndromes.
        c := (others => x"00");
        bpoly := (others => x"00");
        c(0) := x"01";
        bpoly(0) := x"01";
        bprev := x"01";

        for n in 0 to 15 loop
            d := input_syndromes(n);
            for i in 1 to 16 loop
                if i <= l and i <= n then
                    d := d xor gf_mult(c(i), input_syndromes(n-i));
                end if;
            end loop;
            if d /= x"00" then
                oldc := c;
                scale := gf_div(d, bprev);
                for i in 0 to 16 loop
                    if i + m <= 16 then
                        c(i+m) := c(i+m) xor gf_mult(scale, bpoly(i));
                    end if;
                end loop;
                if 2*l <= n then
                    l := n + 1 - l;
                    bpoly := oldc;
                    bprev := d;
                    m := 1;
                elsif m < 17 then
                    m := m + 1;
                end if;
            elsif m < 17 then
                m := m + 1;
            end if;
        end loop;

        if l = 0 then
            if outv.has_error = '0' then outv.valid := '1'; end if;
            return outv;
        end if;
        if l > 8 then return outv; end if;

        -- Chien search. X_j = alpha^(11*(254-j)); roots are X_j^-1.
        found := 0;
        for j in 0 to 254 loop
            xval := gf_pow_alpha((11*(254-j)) mod 255);
            z := gf_inverse(xval);
            evalv := c(0);
            power := x"01";
            for i in 1 to 16 loop
                power := gf_mult(power, z);
                evalv := evalv xor gf_mult(c(i), power);
            end loop;
            if evalv = x"00" then
                if found < 8 then
                    pos(found) := j;
                    xpos(found) := xval;
                end if;
                found := found + 1;
            end if;
        end loop;
        if found /= l or found > 8 then return outv; end if;

        -- Solve S_k = sum(error_magnitude_q * X_q^(120+k)) for k=0..l-1.
        for r in 0 to 7 loop
            for col in 0 to 8 loop mat(r)(col) := x"00"; end loop;
        end loop;
        for r in 0 to l-1 loop
            for col in 0 to l-1 loop
                mat(r)(col) := gf_pow_alpha(0);
                power := gf_pow_alpha((11*(120+r)*(254-pos(col))) mod 255);
                mat(r)(col) := power;
            end loop;
            mat(r)(l) := input_syndromes(r);
        end loop;

        -- Gaussian elimination over GF(256).
        for col in 0 to l-1 loop
            pivot := col;
            pivot_found := false;
            for scan_row in 0 to l-1 loop
                if scan_row >= col and not pivot_found and
                   mat(scan_row)(col) /= x"00" then
                    pivot := scan_row;
                    pivot_found := true;
                end if;
            end loop;
            if not pivot_found then
                ok := false;
            else
                if pivot /= col then
                    for q in 0 to l loop
                        tmp := mat(col)(q);
                        mat(col)(q) := mat(pivot)(q);
                        mat(pivot)(q) := tmp;
                    end loop;
                end if;
                tmp := gf_inverse(mat(col)(col));
                for q in col to l loop mat(col)(q) := gf_mult(mat(col)(q), tmp); end loop;
                for r in 0 to l-1 loop
                    if r /= col then
                        tmp := mat(r)(col);
                        for q in col to l loop
                            mat(r)(q) := mat(r)(q) xor gf_mult(tmp, mat(col)(q));
                        end loop;
                    end if;
                end loop;
            end if;
        end loop;
        if not ok then return outv; end if;

        for i in 0 to l-1 loop mag(i) := mat(i)(l); end loop;
        corrected_tmp := input_symbols;
        for i in 0 to l-1 loop
            corrected_tmp(pos(i)) := corrected_tmp(pos(i)) xor mag(i);
        end loop;

        -- Never report success unless all 16 corrected syndromes are zero.
        for r in 0 to 15 loop
            if calc_syndrome(corrected_tmp, r) /= x"00" then ok := false; end if;
        end loop;
        if ok then
            outv.corrected := corrected_tmp;
            outv.valid := '1';
        end if;
        return outv;
    end function;

begin
    process(clk)
        variable syndrome : std_logic_vector(7 downto 0);
        variable exponent : integer range 0 to 254;
        variable decoded : decode_result;
        variable output_word : std_logic_vector(2039 downto 0);
        variable syms_tmp : symbol_array;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                index <= 0;
                busy <= '0';
                done <= '0';
                error_detect <= '0';
                correction_valid <= '0';
                codeword_out <= (others => '0');
                bad <= '0';
                syndromes <= (others => (others => '0'));
                symbols <= (others => (others => '0'));
            else
                done <= '0';
                case state is
                    when IDLE =>
                        busy <= '0';
                        if start = '1' then
                            for i in 0 to 254 loop
                                symbols(i) <= dual_to_poly(codeword_in(2039-8*i downto 2032-8*i));
                            end loop;
                            index <= 0;
                            bad <= '0';
                            error_detect <= '0';
                            correction_valid <= '0';
                            codeword_out <= codeword_in;
                            busy <= '1';
                            state <= CALCULATE;
                        end if;
                    when CALCULATE =>
                        syndrome := (others => '0');
                        for j in 0 to 254 loop
                            exponent := ((254-j) * (11*(120+index))) mod 255;
                            syndrome := syndrome xor gf_mult(symbols(j), gf_pow_alpha(exponent));
                        end loop;
                        syndromes(index) <= syndrome;
                        if syndrome /= x"00" then bad <= '1'; end if;
                        if index = 15 then
                            state <= CHECK;
                        else
                            index <= index + 1;
                        end if;
                    when CHECK =>
                        syms_tmp := symbols;
                        decoded := decode_rs(syms_tmp, syndromes);
                        error_detect <= bad;
                        correction_valid <= decoded.valid;
                        if decoded.valid = '1' then
                            output_word := (others => '0');
                            for i in 0 to 254 loop
                                output_word(2039-8*i downto 2032-8*i) := poly_to_dual(decoded.corrected(i));
                            end loop;
                            codeword_out <= output_word;
                        end if;
                        busy <= '0';
                        done <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
