-- ═══════════════════════════════════════════════════════════════════════════
-- Datapath — tüm modülleri MUX'larla bağlayan veri yolu
-- ───────────────────────────────────────────────────────────────────────────
-- Hesap yapmaz; veriyi doğru yere yönlendirir. "Hangi veri nereye" kararını
-- dışarıdan gelen kontrol sinyalleri verir. İçinde PC, Memory, IR, Register
-- File, ALU ve ara register'lar (A, B, ALUOut, MDR) bulunur.
--
-- MUX'lar (kontrol sinyali → seçenekler):
--   IorD      ior_d        0=PC               1=ALUOut
--   MemToReg  mem_to_reg   0=ALUOut           1=MDR
--   RegDst    reg_dst      0=rt               1=rd
--   ALUSrcA   alu_src_a    00=PC  01=A        10=ALUOut (ADDI3 geri besleme)
--   ALUSrcB   alu_src_b    000=B 001=4 010=sx16 011=sx16<<2 100=sx11 (ADDI3)
--   PCSource  pc_source    00=ALU sonucu(PC+4) 01=ALUOut(branch) 10=jump
-- A,B,ALUOut,MDR her saykıl yüklenir (en='1' sabit) — standart multi-cycle.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity datapath is
    generic (
        INIT_FILE : string := ""
    );
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;

        -- Kontrol sinyalleri (control_unit'ten)
        pc_write   : in  STD_LOGIC;
        ir_write   : in  STD_LOGIC;
        reg_write  : in  STD_LOGIC;
        mem_read   : in  STD_LOGIC;
        mem_write  : in  STD_LOGIC;
        ior_d      : in  STD_LOGIC_VECTOR(1 downto 0);
        mem_to_reg : in  STD_LOGIC_VECTOR(1 downto 0);
        reg_dst    : in  STD_LOGIC_VECTOR(1 downto 0);
        reg1_sel   : in  STD_LOGIC;                      -- 0=rs, 1=$sp
        reg2_sel   : in  STD_LOGIC;                      -- 0=rt, 1=rs (push verisi)
        alu_src_a  : in  STD_LOGIC_VECTOR(1 downto 0);
        alu_src_b  : in  STD_LOGIC_VECTOR(2 downto 0);
        pc_source  : in  STD_LOGIC_VECTOR(1 downto 0);
        alu_ctrl   : in  STD_LOGIC_VECTOR(3 downto 0);

        -- Durum bilgisi (control_unit'e)
        opcode     : out STD_LOGIC_VECTOR(5 downto 0);
        funct      : out STD_LOGIC_VECTOR(5 downto 0);
        zero       : out STD_LOGIC;
        neg        : out STD_LOGIC;

        -- Gözlem portları
        dbg_reg    : in  STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
        dbg_data   : out STD_LOGIC_VECTOR(31 downto 0);
        pc_debug   : out STD_LOGIC_VECTOR(31 downto 0);
        instr_debug: out STD_LOGIC_VECTOR(31 downto 0)
    );
end datapath;

architecture Behavioral of datapath is

    signal pc_out      : STD_LOGIC_VECTOR(31 downto 0);
    signal pc_next     : STD_LOGIC_VECTOR(31 downto 0);

    signal mem_addr    : STD_LOGIC_VECTOR(31 downto 0);
    signal mem_rdata   : STD_LOGIC_VECTOR(31 downto 0);

    -- IR alanları
    signal ir_opcode   : STD_LOGIC_VECTOR(5 downto 0);
    signal ir_rs       : STD_LOGIC_VECTOR(4 downto 0);
    signal ir_rt       : STD_LOGIC_VECTOR(4 downto 0);
    signal ir_rd       : STD_LOGIC_VECTOR(4 downto 0);
    signal ir_shamt    : STD_LOGIC_VECTOR(4 downto 0);
    signal ir_funct    : STD_LOGIC_VECTOR(5 downto 0);
    signal ir_imm      : STD_LOGIC_VECTOR(15 downto 0);
    signal ir_addr     : STD_LOGIC_VECTOR(25 downto 0);
    signal ir_full     : STD_LOGIC_VECTOR(31 downto 0);

    -- Register file
    signal reg_rdata1  : STD_LOGIC_VECTOR(31 downto 0);
    signal reg_rdata2  : STD_LOGIC_VECTOR(31 downto 0);
    signal write_reg   : STD_LOGIC_VECTOR(4 downto 0);
    signal write_data  : STD_LOGIC_VECTOR(31 downto 0);
    signal read_reg1_m : STD_LOGIC_VECTOR(4 downto 0);
    signal read_reg2_m : STD_LOGIC_VECTOR(4 downto 0);

    constant SP_REG : STD_LOGIC_VECTOR(4 downto 0) := "11101";  -- $sp = $29

    -- Ara register'lar
    signal A_out       : STD_LOGIC_VECTOR(31 downto 0);
    signal B_out       : STD_LOGIC_VECTOR(31 downto 0);
    signal alu_out_reg : STD_LOGIC_VECTOR(31 downto 0);
    signal mdr_out     : STD_LOGIC_VECTOR(31 downto 0);

    -- ALU
    signal alu_a       : STD_LOGIC_VECTOR(31 downto 0);
    signal alu_b       : STD_LOGIC_VECTOR(31 downto 0);
    signal alu_result  : STD_LOGIC_VECTOR(31 downto 0);
    signal alu_zero    : STD_LOGIC;

    -- Yardımcı kombinasyonel değerler
    signal signext16   : STD_LOGIC_VECTOR(31 downto 0);
    signal signext16_sh: STD_LOGIC_VECTOR(31 downto 0);
    signal signext11   : STD_LOGIC_VECTOR(31 downto 0);
    signal jump_addr   : STD_LOGIC_VECTOR(31 downto 0);

begin

    -- İşaret genişletme ve kaydırma (kombinasyonel)
    signext16    <= std_logic_vector(resize(signed(ir_imm), 32));
    signext16_sh <= signext16(29 downto 0) & "00";                          -- imm<<2 (branch)
    signext11    <= std_logic_vector(resize(signed(ir_imm(10 downto 0)), 32));  -- ADDI3
    jump_addr    <= pc_out(31 downto 28) & ir_addr & "00";

    PC_INST: entity work.pc
        port map (
            clk      => clk,
            reset    => reset,
            pc_write => pc_write,
            pc_next  => pc_next,
            pc_out   => pc_out
        );

    -- PCSource MUX: PC'ye ne yazılacak?
    with pc_source select
        pc_next <= alu_result   when "00",   -- IF'te PC+4
                   alu_out_reg  when "01",   -- branch hedefi (ID'de saklandı)
                   jump_addr    when "10",   -- jump
                   alu_result   when others;

    -- IorD MUX: bellek adresi kaynağı
    with ior_d select
        mem_addr <= pc_out      when "00",   -- komut çek (PC)
                    alu_out_reg when "01",   -- lw/sw efektif adres
                    A_out       when "10",   -- pop: adres = $sp (A'da)
                    pc_out      when others;

    MEM_INST: entity work.memory
        generic map ( INIT_FILE => INIT_FILE )
        port map (
            clk        => clk,
            mem_read   => mem_read,
            mem_write  => mem_write,
            address    => mem_addr,
            write_data => B_out,          -- sw/push belleğe B'yi (reg[rt]) yazar
            read_data  => mem_rdata
        );

    IR_INST: entity work.instruction_register
        port map (
            clk       => clk,
            ir_write  => ir_write,
            instr_in  => mem_rdata,
            opcode    => ir_opcode,
            rs        => ir_rs,
            rt        => ir_rt,
            rd        => ir_rd,
            shamt     => ir_shamt,
            funct     => ir_funct,
            immediate => ir_imm,
            address   => ir_addr,
            instr_out => ir_full
        );

    -- MDR: bellekten okunan veriyi WB saykılına taşır (lw/pop)
    MDR_INST: entity work.simple_register
        port map ( clk => clk, en => '1', d => mem_rdata, q => mdr_out );

    -- Register file okuma portu MUX'ları (push/pop/swap için)
    read_reg1_m <= ir_rs when reg1_sel = '0' else SP_REG;   -- 1=$sp
    read_reg2_m <= ir_rt when reg2_sel = '0' else ir_rs;    -- 1=rs (push verisi)

    -- RegDst MUX: yazılacak register
    with reg_dst select
        write_reg <= ir_rt  when "00",   -- I-type
                     ir_rd  when "01",   -- R-type / ADDI3
                     SP_REG when "10",   -- push/pop: $sp güncelle
                     ir_rs  when "11",   -- swap: rs'e yaz
                     ir_rt  when others;

    -- MemToReg MUX: geri yazılacak veri
    with mem_to_reg select
        write_data <= alu_out_reg when "00",   -- ALU sonucu
                      mdr_out     when "01",   -- bellekten (lw/pop)
                      A_out       when "10",   -- swap: A'yı rt'ye yaz
                      B_out       when "11",   -- swap: B'yi rs'e yaz
                      alu_out_reg when others;

    RF_INST: entity work.register_file
        port map (
            clk        => clk,
            reg_write  => reg_write,
            read_reg1  => read_reg1_m,
            read_reg2  => read_reg2_m,
            write_reg  => write_reg,
            write_data => write_data,
            read_data1 => reg_rdata1,
            read_data2 => reg_rdata2,
            dbg_reg    => dbg_reg,
            dbg_data   => dbg_data
        );

    -- A ve B: ID saykılında okunan register değerlerini saklar
    A_INST: entity work.simple_register
        port map ( clk => clk, en => '1', d => reg_rdata1, q => A_out );
    B_INST: entity work.simple_register
        port map ( clk => clk, en => '1', d => reg_rdata2, q => B_out );

    -- ALUSrcA MUX: 1. operand
    with alu_src_a select
        alu_a <= pc_out      when "00",   -- PC
                 A_out       when "01",   -- register operandı (rs)
                 alu_out_reg when "10",   -- ADDI3: önceki ALUOut'u geri besle
                 (others => '0') when others;

    -- ALUSrcB MUX: 2. operand
    with alu_src_b select
        alu_b <= B_out          when "000",  -- register operandı (rt)
                 x"00000004"    when "001",  -- sabit 4 (PC+4)
                 signext16      when "010",  -- 16-bit imm (addi, lw, sw)
                 signext16_sh   when "011",  -- imm<<2 (branch hedefi)
                 signext11      when "100",  -- 11-bit imm (ADDI3)
                 (others => '0') when others;

    ALU_INST: entity work.alu
        port map (
            a        => alu_a,
            b        => alu_b,
            alu_ctrl => alu_ctrl,
            result   => alu_result,
            zero     => alu_zero
        );

    -- ALUOut: ALU sonucunu sonraki saykıla taşır
    ALUOUT_INST: entity work.simple_register
        port map ( clk => clk, en => '1', d => alu_result, q => alu_out_reg );

    -- Durum çıkışları (control_unit'e)
    opcode <= ir_opcode;
    funct  <= ir_funct;
    zero   <= alu_zero;
    neg    <= alu_result(31);   -- sonuç negatif mi (bgt için)

    pc_debug    <= pc_out;
    instr_debug <= ir_full;

end Behavioral;
