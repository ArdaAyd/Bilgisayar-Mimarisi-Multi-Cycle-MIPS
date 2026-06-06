-- ═══════════════════════════════════════════════════════════════════════════
-- Control Unit — multi-cycle CPU'nun beyni (FSM / durum makinesi)
-- ───────────────────────────────────────────────────────────────────────────
-- Her komut saykıllara yayılır (IF→ID→EX→MEM→WB). FSM hangi durumda olduğumuzu
-- takip eder ve her durumda datapath'in MUX/enable sinyallerini üretir.
-- ALU'ya doğrudan değil, alu_op (2-bit) üretir; alu_control 4-bit alu_ctrl'ü çözer.
--
-- İki süreçli FSM:
--   - state_reg süreci: clock kenarında durum geçişi (reset → S_FETCH)
--   - comb süreci: mevcut duruma göre çıkışlar + sonraki durum
-- Latch oluşmaması için comb sürecinde tüm çıkışlara en başta varsayılan atanır.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity control_unit is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        opcode     : in  STD_LOGIC_VECTOR(5 downto 0);
        funct      : in  STD_LOGIC_VECTOR(5 downto 0);   -- swap ayrımı için
        zero       : in  STD_LOGIC;
        neg        : in  STD_LOGIC;                       -- ALU sonuç işareti (bgt)

        pc_write   : out STD_LOGIC;
        ir_write   : out STD_LOGIC;
        reg_write  : out STD_LOGIC;
        mem_read   : out STD_LOGIC;
        mem_write  : out STD_LOGIC;
        ior_d      : out STD_LOGIC_VECTOR(1 downto 0);
        mem_to_reg : out STD_LOGIC_VECTOR(1 downto 0);
        reg_dst    : out STD_LOGIC_VECTOR(1 downto 0);
        reg1_sel   : out STD_LOGIC;                       -- 0=rs, 1=$sp
        reg2_sel   : out STD_LOGIC;                       -- 0=rt, 1=rs
        alu_src_a  : out STD_LOGIC_VECTOR(1 downto 0);
        alu_src_b  : out STD_LOGIC_VECTOR(2 downto 0);
        pc_source  : out STD_LOGIC_VECTOR(1 downto 0);
        alu_op     : out STD_LOGIC_VECTOR(1 downto 0)
    );
end control_unit;

architecture Behavioral of control_unit is

    type state_t is (
        S_FETCH, S_DECODE,
        S_RTYPE_EX, S_RTYPE_WB,
        S_ITYPE_EX, S_ITYPE_WB,
        S_MEM_ADDR, S_MEM_READ, S_MEM_WB, S_MEM_WRITE,
        S_BRANCH, S_JUMP,
        S_ADDI3_EX1, S_ADDI3_EX2, S_ADDI3_WB,
        S_SWAP_W1, S_SWAP_W2,                       -- swap: iki yazma
        S_PUSH_ADDR, S_PUSH_MEM, S_PUSH_SP,         -- push: adres→yaz→$sp
        S_POP_READ, S_POP_WB, S_POP_SP              -- pop: oku→yaz→$sp
    );
    signal state, next_state : state_t := S_FETCH;

    -- Opcode sabitleri (assembler.py ile AYNI)
    constant OPC_RTYPE : STD_LOGIC_VECTOR(5 downto 0) := "000000";  -- 0x00
    constant OPC_ADDI  : STD_LOGIC_VECTOR(5 downto 0) := "001000";  -- 0x08
    constant OPC_SLTI  : STD_LOGIC_VECTOR(5 downto 0) := "001010";  -- 0x0a
    constant OPC_ANDI  : STD_LOGIC_VECTOR(5 downto 0) := "001100";  -- 0x0c
    constant OPC_ORI   : STD_LOGIC_VECTOR(5 downto 0) := "001101";  -- 0x0d
    constant OPC_XORI  : STD_LOGIC_VECTOR(5 downto 0) := "001110";  -- 0x0e
    constant OPC_LW    : STD_LOGIC_VECTOR(5 downto 0) := "100011";  -- 0x23
    constant OPC_SW    : STD_LOGIC_VECTOR(5 downto 0) := "101011";  -- 0x2b
    constant OPC_BEQ   : STD_LOGIC_VECTOR(5 downto 0) := "000100";  -- 0x04
    constant OPC_BNE   : STD_LOGIC_VECTOR(5 downto 0) := "000101";  -- 0x05
    constant OPC_LOADI : STD_LOGIC_VECTOR(5 downto 0) := "010001";  -- 0x11
    constant OPC_BGT   : STD_LOGIC_VECTOR(5 downto 0) := "010010";  -- 0x12
    constant OPC_J     : STD_LOGIC_VECTOR(5 downto 0) := "000010";  -- 0x02
    constant OPC_ADDI3 : STD_LOGIC_VECTOR(5 downto 0) := "010000";  -- 0x10
    constant OPC_PUSH  : STD_LOGIC_VECTOR(5 downto 0) := "010011";  -- 0x13
    constant OPC_POP   : STD_LOGIC_VECTOR(5 downto 0) := "010100";  -- 0x14
    constant F_SWAP    : STD_LOGIC_VECTOR(5 downto 0) := "101101";  -- 0x2d (R-type)

begin

    -- Durum register'ı (senkron geçiş)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= S_FETCH;
            else
                state <= next_state;
            end if;
        end if;
    end process;

    -- Kombinasyonel: çıkışlar + sonraki durum
    process(state, opcode, funct, zero, neg)
    begin
        -- Güvenli varsayılanlar (latch önler)
        pc_write   <= '0';
        ir_write   <= '0';
        reg_write  <= '0';
        mem_read   <= '0';
        mem_write  <= '0';
        ior_d      <= "00";
        mem_to_reg <= "00";
        reg_dst    <= "00";
        reg1_sel   <= '0';
        reg2_sel   <= '0';
        alu_src_a  <= "00";
        alu_src_b  <= "000";
        pc_source  <= "00";
        alu_op     <= "00";
        next_state <= S_FETCH;

        case state is

            -- IF: komutu oku, IR'a kilitle, PC=PC+4
            when S_FETCH =>
                mem_read   <= '1';
                ir_write   <= '1';
                alu_src_a  <= "00";
                alu_src_b  <= "001";
                alu_op     <= "00";
                pc_source  <= "00";
                pc_write   <= '1';
                next_state <= S_DECODE;

            -- ID: A,B yüklenir; branch hedefini önceden hesapla; opcode'a göre dallan
            when S_DECODE =>
                alu_src_a  <= "00";
                alu_src_b  <= "011";      -- signext16 << 2 → ALUOut = branch hedefi
                alu_op     <= "00";
                case opcode is
                    when OPC_RTYPE =>
                        if funct = F_SWAP then     -- swap de R-type, funct ile ayrılır
                            next_state <= S_SWAP_W1;
                        else
                            next_state <= S_RTYPE_EX;
                        end if;
                    when OPC_ADDI | OPC_SLTI | OPC_ANDI | OPC_ORI | OPC_XORI |
                         OPC_LOADI =>
                        next_state <= S_ITYPE_EX;
                    when OPC_LW | OPC_SW => next_state <= S_MEM_ADDR;
                    when OPC_BEQ | OPC_BNE | OPC_BGT => next_state <= S_BRANCH;
                    when OPC_J     => next_state <= S_JUMP;
                    when OPC_ADDI3 => next_state <= S_ADDI3_EX1;
                    when OPC_PUSH  =>
                        reg1_sel   <= '1';   -- A=$sp, B=reg[rs] (itilecek veri)
                        reg2_sel   <= '1';
                        next_state <= S_PUSH_ADDR;
                    when OPC_POP   =>
                        reg1_sel   <= '1';   -- A=$sp
                        next_state <= S_POP_READ;
                    when others    => next_state <= S_FETCH;
                end case;

            -- R-type EX: ALUOut = A op B (funct'a göre)
            when S_RTYPE_EX =>
                alu_src_a  <= "01";
                alu_src_b  <= "000";
                alu_op     <= "10";
                next_state <= S_RTYPE_WB;

            -- R-type WB: rd <- ALUOut
            when S_RTYPE_WB =>
                reg_dst    <= "01";
                mem_to_reg <= "00";
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- I-type EX: ALUOut = A op signext16
            when S_ITYPE_EX =>
                alu_src_a  <= "01";
                alu_src_b  <= "010";
                alu_op     <= "10";
                next_state <= S_ITYPE_WB;

            -- I-type WB: rt <- ALUOut
            when S_ITYPE_WB =>
                reg_dst    <= "00";
                mem_to_reg <= "00";
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- lw/sw: efektif adres = A + signext16 → ALUOut
            when S_MEM_ADDR =>
                alu_src_a  <= "01";
                alu_src_b  <= "010";
                alu_op     <= "00";
                if opcode = OPC_LW then
                    next_state <= S_MEM_READ;
                else
                    next_state <= S_MEM_WRITE;
                end if;

            -- lw: bellekten oku → MDR
            when S_MEM_READ =>
                ior_d      <= "01";       -- adres = ALUOut
                mem_read   <= '1';
                next_state <= S_MEM_WB;

            -- lw WB: rt <- MDR
            when S_MEM_WB =>
                reg_dst    <= "00";
                mem_to_reg <= "01";       -- kaynak MDR (bellek)
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- sw: MEM[ALUOut] <- B
            when S_MEM_WRITE =>
                ior_d      <= "01";
                mem_write  <= '1';
                next_state <= S_FETCH;

            -- Branch: A-B hesapla, koşula göre PC <- branch hedefi
            when S_BRANCH =>
                alu_src_a  <= "01";
                alu_src_b  <= "000";
                alu_op     <= "01";       -- SUB (zero/neg bayrakları)
                pc_source  <= "01";       -- PC <- ALUOut (ID'de hesaplanan hedef)
                case opcode is
                    when OPC_BEQ => pc_write <= zero;
                    when OPC_BNE => pc_write <= not zero;
                    when OPC_BGT => pc_write <= (not zero) and (not neg);
                    when others  => pc_write <= '0';
                end case;
                next_state <= S_FETCH;

            -- Jump: PC <- jump adresi
            when S_JUMP =>
                pc_source  <= "10";
                pc_write   <= '1';
                next_state <= S_FETCH;

            -- ADDI3 EX1: ALUOut = A + B (rs+rt)
            when S_ADDI3_EX1 =>
                alu_src_a  <= "01";
                alu_src_b  <= "000";
                alu_op     <= "00";
                next_state <= S_ADDI3_EX2;

            -- ADDI3 EX2: ALUOut = ALUOut + signext11 (geri besleme)
            when S_ADDI3_EX2 =>
                alu_src_a  <= "10";       -- önceki ALUOut
                alu_src_b  <= "100";      -- signext11
                alu_op     <= "00";
                next_state <= S_ADDI3_WB;

            -- ADDI3 WB: rd <- ALUOut
            when S_ADDI3_WB =>
                reg_dst    <= "01";
                mem_to_reg <= "00";
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- SWAP: reg[rt] <- A(eski reg[rs]); reg[rs] <- B(eski reg[rt]).
            -- Register file'da okuma yazmadan ÖNCEKİ değeri verir; bu yüzden W1'de
            -- reg[rt]'ye yazarken B hâlâ eski reg[rt]'yi tutar → W2 doğru olur.
            when S_SWAP_W1 =>
                reg_dst    <= "00";       -- rt <- A
                mem_to_reg <= "10";
                reg_write  <= '1';
                next_state <= S_SWAP_W2;

            when S_SWAP_W2 =>
                reg_dst    <= "11";       -- rs <- B
                mem_to_reg <= "11";
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- PUSH: $sp -= 4; MEM[$sp] <- reg[rs]
            when S_PUSH_ADDR =>
                reg1_sel   <= '1';        -- A=$sp, B=reg[rs] sabit kalsın
                reg2_sel   <= '1';
                alu_src_a  <= "01";
                alu_src_b  <= "001";
                alu_op     <= "01";       -- ALUOut = $sp - 4
                next_state <= S_PUSH_MEM;

            when S_PUSH_MEM =>
                reg1_sel   <= '1';
                reg2_sel   <= '1';
                ior_d      <= "01";       -- adres = ALUOut ($sp-4)
                mem_write  <= '1';
                -- ALUOut her saykıl yenilendiği için $sp-4'ü S_PUSH_SP'ye taşı:
                alu_src_a  <= "01";
                alu_src_b  <= "001";
                alu_op     <= "01";
                next_state <= S_PUSH_SP;

            when S_PUSH_SP =>
                reg_dst    <= "10";       -- $sp <- ALUOut ($sp-4)
                mem_to_reg <= "00";
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- POP: reg[rd] <- MEM[$sp]; $sp += 4   (rd, rt alanında)
            when S_POP_READ =>
                reg1_sel   <= '1';        -- A=$sp
                ior_d      <= "10";       -- adres = A ($sp)
                mem_read   <= '1';
                alu_src_a  <= "01";
                alu_src_b  <= "001";
                alu_op     <= "00";       -- ALUOut = $sp + 4
                next_state <= S_POP_WB;

            when S_POP_WB =>
                reg1_sel   <= '1';        -- ALUOut'u $sp+4 olarak koru
                alu_src_a  <= "01";
                alu_src_b  <= "001";
                alu_op     <= "00";
                reg_dst    <= "00";       -- rt(=rd) <- MDR
                mem_to_reg <= "01";
                reg_write  <= '1';
                next_state <= S_POP_SP;

            when S_POP_SP =>
                reg_dst    <= "10";       -- $sp <- ALUOut ($sp+4)
                mem_to_reg <= "00";
                reg_write  <= '1';
                next_state <= S_FETCH;

            when others =>
                next_state <= S_FETCH;

        end case;
    end process;

end Behavioral;
