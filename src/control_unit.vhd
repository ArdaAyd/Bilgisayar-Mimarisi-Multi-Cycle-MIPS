-- ═══════════════════════════════════════════════════════════════════════════
-- Control Unit — multi-cycle CPU'nun beyni (FSM / durum makinesi)
-- ───────────────────────────────────────────────────────────────────────────
-- Her komut saykıllara yayılır: IF → ID → EX → MEM → WB. Bu FSM hangi durumda
-- olduğumuzu takip eder ve her durumda datapath'in MUX/enable sinyallerini üretir.
--
-- Çıkışları doğrudan ALU'ya değil; alu_op (2-bit) üretip alu_control'e verir,
-- o da funct/opcode'a bakıp 4-bit alu_ctrl'ü çözer.
--
-- KAPSAM (Faz 4): çekirdek MIPS + mul, loadi, bgt, addi3.
--   push/pop/swap Faz 5'te eklenecek (stack pointer + çift yazma gerektirir).
--
-- İki süreçli FSM:
--   - state_reg süreci: clock kenarında durum geçişi (reset → S_FETCH)
--   - comb süreci: mevcut duruma göre çıkışlar + sonraki durum
-- Latch oluşmaması için comb sürecinde TÜM çıkışlara en başta varsayılan atanır.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity control_unit is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        opcode     : in  STD_LOGIC_VECTOR(5 downto 0);   -- IR opcode (datapath'ten)
        funct      : in  STD_LOGIC_VECTOR(5 downto 0);   -- IR funct (swap ayrımı için)
        zero       : in  STD_LOGIC;                       -- ALU zero bayrağı
        neg        : in  STD_LOGIC;                       -- ALU sonuç işareti (bgt)

        -- ── datapath'e giden kontrol sinyalleri ──
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

    -- ── Durumlar ─────────────────────────────────────────────────────────────
    type state_t is (
        S_FETCH, S_DECODE,
        S_RTYPE_EX, S_RTYPE_WB,
        S_ITYPE_EX, S_ITYPE_WB,
        S_MEM_ADDR, S_MEM_READ, S_MEM_WB, S_MEM_WRITE,
        S_BRANCH, S_JUMP,
        S_ADDI3_EX1, S_ADDI3_EX2, S_ADDI3_WB,
        S_SWAP_W1, S_SWAP_W2,                       -- swap: iki yazma
        S_PUSH_ADDR, S_PUSH_MEM, S_PUSH_SP,         -- push: adres→belleğe yaz→$sp güncelle
        S_POP_READ, S_POP_WB, S_POP_SP              -- pop: oku→$rd yaz→$sp güncelle
    );
    signal state, next_state : state_t := S_FETCH;

    -- ── Opcode sabitleri (assembler.py ile AYNI) ─────────────────────────────
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

    -- ══ Durum register'ı (senkron geçiş) ═════════════════════════════════════
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

    -- ══ Kombinasyonel: çıkışlar + sonraki durum ══════════════════════════════
    process(state, opcode, funct, zero, neg)
    begin
        -- ── Güvenli varsayılanlar (latch önler) ──
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

            -- ── IF: komutu oku, IR'a yaz, PC=PC+4 ──
            when S_FETCH =>
                mem_read   <= '1';        -- adres=PC (ior_d=0)
                ir_write   <= '1';        -- komutu IR'a kilitle
                alu_src_a  <= "00";       -- ALU a = PC
                alu_src_b  <= "001";      -- ALU b = 4
                alu_op     <= "00";       -- ADD
                pc_source  <= "00";       -- PC <- ALU sonucu (PC+4)
                pc_write   <= '1';
                next_state <= S_DECODE;

            -- ── ID: A,B otomatik yüklenir; branch hedefini önceden hesapla ──
            when S_DECODE =>
                alu_src_a  <= "00";       -- ALU a = PC (artık PC+4)
                alu_src_b  <= "011";      -- ALU b = signext16 << 2
                alu_op     <= "00";       -- ADD → ALUOut = branch hedefi
                -- sonraki durum: opcode'a göre dallan
                case opcode is
                    when OPC_RTYPE =>
                        -- swap de R-type; funct ile ayrılır
                        if funct = F_SWAP then
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
                        -- A=$sp, B=reg[rs] olsun diye okuma seçicileri ayarla
                        reg1_sel   <= '1';
                        reg2_sel   <= '1';
                        next_state <= S_PUSH_ADDR;
                    when OPC_POP   =>
                        reg1_sel   <= '1';   -- A=$sp
                        next_state <= S_POP_READ;
                    when others    => next_state <= S_FETCH;  -- bilinmeyen: atla
                end case;

            -- ── R-type EX: ALUOut = A op B ──
            when S_RTYPE_EX =>
                alu_src_a  <= "01";       -- A
                alu_src_b  <= "000";      -- B
                alu_op     <= "10";       -- funct'a göre çöz
                next_state <= S_RTYPE_WB;

            -- ── R-type WB: rd <- ALUOut ──
            when S_RTYPE_WB =>
                reg_dst    <= "01";       -- hedef rd
                mem_to_reg <= "00";       -- kaynak ALUOut
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- ── I-type EX: ALUOut = A op signext16 (addi/slti/andi/ori/xori/loadi) ──
            when S_ITYPE_EX =>
                alu_src_a  <= "01";       -- A (loadi'de reg[0]=0)
                alu_src_b  <= "010";      -- signext16
                alu_op     <= "10";       -- opcode'a göre çöz
                next_state <= S_ITYPE_WB;

            -- ── I-type WB: rt <- ALUOut ──
            when S_ITYPE_WB =>
                reg_dst    <= "00";       -- hedef rt
                mem_to_reg <= "00";       -- kaynak ALUOut
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- ── lw/sw: efektif adres = A + signext16 → ALUOut ──
            when S_MEM_ADDR =>
                alu_src_a  <= "01";       -- A
                alu_src_b  <= "010";      -- signext16
                alu_op     <= "00";       -- ADD
                if opcode = OPC_LW then
                    next_state <= S_MEM_READ;
                else
                    next_state <= S_MEM_WRITE;
                end if;

            -- ── lw: bellekten oku → MDR (her saykıl yüklenir) ──
            when S_MEM_READ =>
                ior_d      <= "01";       -- adres = ALUOut
                mem_read   <= '1';
                next_state <= S_MEM_WB;

            -- ── lw WB: rt <- MDR ──
            when S_MEM_WB =>
                reg_dst    <= "00";       -- hedef rt
                mem_to_reg <= "01";       -- kaynak MDR (bellek)
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- ── sw: belleğe yaz (MEM[ALUOut] <- B) ──
            when S_MEM_WRITE =>
                ior_d      <= "01";       -- adres = ALUOut
                mem_write  <= '1';
                next_state <= S_FETCH;

            -- ── Branch: A-B hesapla, koşula göre PC <- branch hedefi ──
            when S_BRANCH =>
                alu_src_a  <= "01";       -- A
                alu_src_b  <= "000";      -- B
                alu_op     <= "01";       -- SUB (zero/neg bayrakları için)
                pc_source  <= "01";       -- PC <- ALUOut (ID'de hesaplanan hedef)
                case opcode is
                    when OPC_BEQ => pc_write <= zero;
                    when OPC_BNE => pc_write <= not zero;
                    when OPC_BGT => pc_write <= (not zero) and (not neg);
                    when others  => pc_write <= '0';
                end case;
                next_state <= S_FETCH;

            -- ── Jump: PC <- jump adresi ──
            when S_JUMP =>
                pc_source  <= "10";
                pc_write   <= '1';
                next_state <= S_FETCH;

            -- ── ADDI3 EX1: ALUOut = A + B (rs+rt) ──
            when S_ADDI3_EX1 =>
                alu_src_a  <= "01";       -- A
                alu_src_b  <= "000";      -- B
                alu_op     <= "00";       -- ADD
                next_state <= S_ADDI3_EX2;

            -- ── ADDI3 EX2: ALUOut = ALUOut + signext11(imm) ──
            when S_ADDI3_EX2 =>
                alu_src_a  <= "10";       -- önceki ALUOut (geri besleme)
                alu_src_b  <= "100";      -- signext11
                alu_op     <= "00";       -- ADD
                next_state <= S_ADDI3_WB;

            -- ── ADDI3 WB: rd <- ALUOut ──
            when S_ADDI3_WB =>
                reg_dst    <= "01";       -- hedef rd
                mem_to_reg <= "00";       -- kaynak ALUOut
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- ══ SWAP: reg[rt] <- A(reg[rs]); reg[rs] <- B(reg[rt]) ══
            -- Önemli: register file'da okuma-yazma aynı kenarda; okuma yazmadan
            -- ÖNCEKİ değeri verir. Bu yüzden W1'de reg[rt]=A yazılırken B hâlâ
            -- eski reg[rt]'yi yakalar → W2'de doğru değer yazılır.
            when S_SWAP_W1 =>
                reg_dst    <= "00";       -- hedef rt
                mem_to_reg <= "10";       -- kaynak A (eski reg[rs])
                reg_write  <= '1';
                next_state <= S_SWAP_W2;

            when S_SWAP_W2 =>
                reg_dst    <= "11";       -- hedef rs
                mem_to_reg <= "11";       -- kaynak B (eski reg[rt])
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- ══ PUSH: $sp -= 4; MEM[$sp] <- reg[rs] ══
            -- DECODE'da reg1_sel=1 (A=$sp), reg2_sel=1 (B=reg[rs], itilecek veri).
            when S_PUSH_ADDR =>
                reg1_sel   <= '1';        -- A = $sp (sabit kalsın)
                reg2_sel   <= '1';        -- B = reg[rs]
                alu_src_a  <= "01";       -- A ($sp)
                alu_src_b  <= "001";      -- 4
                alu_op     <= "01";       -- SUB → ALUOut = $sp - 4
                next_state <= S_PUSH_MEM;

            when S_PUSH_MEM =>
                reg1_sel   <= '1';
                reg2_sel   <= '1';        -- B = reg[rs] (belleğe yazılacak)
                ior_d      <= "01";       -- adres = ALUOut ($sp-4)
                mem_write  <= '1';        -- MEM[$sp-4] <- B
                -- ALUOut her saykıl yenilenir; $sp-4'ü S_PUSH_SP için koru:
                alu_src_a  <= "01";       -- A ($sp)
                alu_src_b  <= "001";      -- 4
                alu_op     <= "01";       -- SUB → ALUOut = $sp - 4 (sabit kalsın)
                next_state <= S_PUSH_SP;

            when S_PUSH_SP =>
                reg_dst    <= "10";       -- hedef $sp
                mem_to_reg <= "00";       -- kaynak ALUOut ($sp-4)
                reg_write  <= '1';
                next_state <= S_FETCH;

            -- ══ POP: reg[rd] <- MEM[$sp]; $sp += 4 ══
            -- DECODE'da reg1_sel=1 (A=$sp). rd, rt alanında (reg_dst=00).
            when S_POP_READ =>
                reg1_sel   <= '1';        -- A = $sp
                ior_d      <= "10";       -- adres = A ($sp)
                mem_read   <= '1';        -- MDR <- MEM[$sp]
                alu_src_a  <= "01";       -- A ($sp)
                alu_src_b  <= "001";      -- 4
                alu_op     <= "00";       -- ADD → ALUOut = $sp + 4
                next_state <= S_POP_WB;

            when S_POP_WB =>
                reg1_sel   <= '1';        -- A=$sp sabit kalsın (ALUOut korunsun)
                alu_src_a  <= "01";
                alu_src_b  <= "001";
                alu_op     <= "00";       -- ALUOut'u $sp+4 olarak tut
                reg_dst    <= "00";       -- hedef rt (=rd)
                mem_to_reg <= "01";       -- kaynak MDR
                reg_write  <= '1';
                next_state <= S_POP_SP;

            when S_POP_SP =>
                reg_dst    <= "10";       -- hedef $sp
                mem_to_reg <= "00";       -- kaynak ALUOut ($sp+4)
                reg_write  <= '1';
                next_state <= S_FETCH;

            when others =>
                next_state <= S_FETCH;

        end case;
    end process;

end Behavioral;
