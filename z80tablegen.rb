#!/usr/bin/env ruby

# rubocop:disable Style/GlobalVars
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/BlockNesting
$r = %w(B C D E H L (HL) A)
$rp = %w(BC DE HL SP)
$rp2 = %w(BC DE HL AF)
$cc = %w(NZ Z NC C PO PE P M)
$alu = ['ADD A,', 'ADC A,', 'SUB', 'SBC A,', 'AND', 'XOR', 'OR', 'CP']
$rot = %w(RLC RRC RL RR SLA SRA SLL SRL)
$im = %w(0 0 1 2 0 0 1 2)

def bli(a, b)
  case a
  when 4
    %w(LDI CPI INI OUTI)[b]
  when 5
    %w(LDD CPD IND OUTD)[b]
  when 6
    %w(LDIR CPIR INIR OTIR)[b]
  when 7
    %w(LDDR CPDR INDR OTDR)[b]
  end
end

def x(byte)
  (0b1100_0000 & byte) >> 6
end

def y(byte)
  (0b0011_1000 & byte) >> 3
end

def z(byte)
  0b0000_0111 & byte
end

def p(byte)
  (0b0011_0000 & byte) >> 4
end

def q(byte)
  (0b0000_1000 & byte) >> 3
end

def decode_regular(i)
  case x(i)
  when 0
    case z(i)
    when 0
      case y(i)
      when 0
        'NOP'
      when 1
        "EX AF, AF'"
      when 2
        'DJNZ e'
      when 3
        'JR e'
      else
        "JR #{$cc[y(i) - 4]}, e"
      end
    when 1
      case q(i)
      when 0
        "LD #{$rp[p(i)]}, NN"
      when 1
        "ADD HL, #{$rp[p(i)]}"
      end
    when 2
      case q(i)
      when 0
        case p(i)
        when 0
          'LD (BC), A'
        when 1
          'LD (DE), A'
        when 2
          'LD (NN), HL'
        when 3
          'LD (NN), A'
        end
      when 1
        case p(i)
        when 0
          'LD A, (BC)'
        when 1
          'LD A, (DE)'
        when 2
          'LD HL, (NN)'
        when 3
          'LD A, (NN)'
        end
      end
    when 3
      case q(i)
      when 0
        "INC #{$rp[p(i)]}"
      when 1
        "DEC #{$rp[p(i)]}"
      end
    when 4
      "INC #{$r[y(i)]}"
    when 5
      "DEC #{$r[y(i)]}"
    when 6
      "LD #{$r[y(i)]}, N"
    when 7
      case y(i)
      when 0
        'RLCA'
      when 1
        'RRCA'
      when 2
        'RLA'
      when 3
        'RRA'
      when 4
        'DAA'
      when 5
        'CPL'
      when 6
        'SCF'
      when 7
        'CCF'
      end
    end
  when 1
    if [z(i), y(i)] == [6, 6]
      'HALT'
    else
      "LD #{$r[y(i)]}, #{$r[z(i)]}"
    end
  when 2
    "#{$alu[y(i)]} #{$r[z(i)]}"
  when 3
    case z(i)
    when 0
      "RET #{$cc[y(i)]}"
    when 1
      case q(i)
      when 0
        "POP #{$rp2[p(i)]}"
      when 1
        case p(i)
        when 0
          'RET'
        when 1
          'EXX'
        when 2
          'JP HL'
        when 3
          'LD SP, HL'
        end
      end
    when 2
      "JP #{$cc[y(i)]}, NN"
    when 3
      case y(i)
      when 0
        'JP NN'
      when 1
        nil # '<CB prefix>'
      when 2
        'OUT (N), A'
      when 3
        'IN A, (N)'
      when 4
        'EX (SP), HL'
      when 5
        'EX DE, HL'
      when 6
        'DI'
      when 7
        'EI'
      end
    when 4
      "CALL #{$cc[y(i)]}, NN"
    when 5
      case q(i)
      when 0
        "PUSH #{$rp2[p(i)]}"
      when 1
        case p(i)
        when 0
          'CALL NN'
        when 1
          nil # '<DD prefix>'
        when 2
          nil # '<ED prefix>'
        when 3
          nil # '<FD prefix>'
        end
      end
    when 6
      "#{$alu[y(i)]} N"
    when 7
      "RST #{format('%02X', y(i) * 8)}"
    end
  end
end

def decode_cb(i)
  case x(i)
  when 0
    "#{$rot[y(i)]} #{$r[z(i)]}"
  when 1
    "BIT #{y(i)}, #{$r[z(i)]}"
  when 2
    "RES #{y(i)}, #{$r[z(i)]}"
  when 3
    "SET #{y(i)}, #{$r[z(i)]}"
  end
end

def decode_ed(i)
  case x(i)
  when 0, 3
    nil # '<invalid>'
  when 1
    case z(i)
    when 0
      if y(i) == 6
        'IN (C)'
      else
        "IN #{$r[y(i)]}, (C)"
      end
    when 1
      if y(i) == 6
        'OUT (C), 0'
      else
        "OUT (C), #{$r[y(i)]}"
      end
    when 2
      case q(i)
      when 0
        "SBC HL, #{$rp[p(i)]}"
      when 1
        "ADC HL, #{$rp[p(i)]}"
      end
    when 3
      case q(i)
      when 0
        "LD (NN), #{$rp[p(i)]}"
      when 1
        "LD #{$rp[p(i)]}, (NN)"
      end
    when 4
      'NEG'
    when 5
      if y(i) == 1
        'RETI'
      else
        'RETN'
      end
    when 6
      "IM #{$im[y(i)]}"
    when 7
      case y(i)
      when 0
        'LD I, A'
      when 1
        'LD R, A'
      when 2
        'LD A, I'
      when 3
        'LD A, R'
      when 4
        'RRD'
      when 5
        'RLD'
      when 6
        nil # 'NOP'
      when 7
        nil # ' NOP'
      end
    end
  when 2
    if y(i) >= 4
      bli y(i), z(i)
    else
      nil # '<invalid>'
    end
  end
end

def separate_instr(instr)
  /^([A-Z]+)( (.*))?$/.match(instr) do |m|
    if m[2]
      [m[1]] + m[3].split(/, /)
    else
      [m[1]]
    end
  end
end

def combine_instr(parts)
  parts = parts.to_a
  if parts.length == 1
    parts[0]
  else
    "#{parts[0]} #{parts.drop(1).join(', ')}"
  end
end

def decode_ddfd(i, dd_or_fd = :dd)
  instr_ = decode_regular(i)
  return if instr_ == 'EX DE, HL' # exception
  return if instr_.nil?
  instr = separate_instr(instr_)

  has_hl = %w(HL H L).any? { |r| instr.include? r }
  has_rhl = instr.include? '(HL)'

  if has_rhl
    combine_instr(instr.map do |item|
                    if item == '(HL)'
                      dd_or_fd == :dd ? '(IX+d)' : '(IY+d)'
                    else
                      item
                    end
                  end)
  elsif has_hl
    combine_instr(instr.map do |item|
                    case item
                    when 'HL'
                      dd_or_fd == :dd ? 'IX' : 'IY'
                    when 'H'
                      dd_or_fd == :dd ? 'IXh' : 'IYh'
                    when 'L'
                      dd_or_fd == :dd ? 'IXl' : 'IYl'
                    else
                      item
                    end
                  end)
  end
end

def decode_dd(i)
  decode_ddfd(i, :dd)
end

def decode_fd(i)
  decode_ddfd(i, :fd)
end

def decode_ddfdcb(i, dd_or_fd = :dd)
  ix = dd_or_fd == :dd ? 'IX' : 'IY'

  case x(i)
  when 0
    if z(i) == 6
      "#{$rot[y(i)]} (#{ix}+d)"
    else
      # "LD #{$r[z(i)]}, #{$rot[y(i)]} (#{ix}+d)"
      "#{$rot[y(i)]} (#{ix}+d), #{$r[z(i)]}"
    end
  when 1
    "BIT #{y(i)}, (#{ix}+d)"
  when 2
    if z(i) == 6
      "RES #{y(i)}, (#{ix}+d)"
    else
      # "LD #{$r[z(i)]}, RES #{y(i)}, (#{ix}+d)"
      "RES #{y(i)}, (#{ix}+d), #{$r[z(i)]}"
    end
  when 3
    if z(i) == 6
      "SET #{y(i)}, (#{ix}+d)"
    else
      # "LD #{$r[z(i)]}, SET #{y(i)}, (#{ix}+d)"
      "SET #{y(i)}, (#{ix}+d), #{$r[z(i)]}"
    end
  end
end

def decode_ddcb(i)
  decode_ddfdcb(i, :dd)
end

def decode_fdcb(i)
  decode_ddfdcb(i, :fd)
end

class Instructions
  def each
    (0..0xff).each { |b| yield [[b], decode_regular(b)] }
    (0..0xff).each { |b| yield [[0xed, b], decode_ed(b)] }
    (0..0xff).each { |b| yield [[0xcb, b], decode_cb(b)] }
    [:dd, :fd].each do |dd_or_fd|
      dd_or_fd_ = dd_or_fd == :dd ? 0xdd : 0xfd
      (0..0xff).each do |b|
        yield [[dd_or_fd_, b], decode_ddfd(b, dd_or_fd)]
      end
      (0..0xff).each do |b|
        yield [[dd_or_fd_, 0xcb, :xx, b], decode_ddfdcb(b, dd_or_fd)]
      end
    end
  end
end

def add_args(instr_pair)
  bytes, instr = instr_pair

  parts = separate_instr(instr)

  has_ix = ['(IX+d)', '(IY+d)'].any? { |ref| parts.include? ref }
  has_ix &&= (bytes.length != 4 || bytes[2] != :xx)
  has_8_arg = ['(N)', 'N', 'e'].any? { |ref| parts.include? ref }
  has_16_arg = ['(NN)', 'NN'].any? { |ref| parts.include? ref }

  if has_ix && has_8_arg
    [bytes + [:xx, :xx], instr]
  elsif has_ix
    [bytes + [:xx], instr]
  elsif has_8_arg
    [bytes + [:xx], instr]
  elsif has_16_arg
    [bytes + [:xx, :xx], instr]
  else
    [bytes, instr]
  end
end

def remove_a(instr_pair)
  bytes, instr = instr_pair
  parts = separate_instr(instr)

  if parts.length == 3 &&
     parts[1] == 'A' &&
     %w(ADC ADD SUB SBC).include?(parts[0])
    [bytes, combine_instr([parts[0], parts[2]])]
  else
    instr_pair
  end
end

def jp_register_in_quotes(instr_pair)
  bytes, instr = instr_pair
  parts = separate_instr(instr)

  if parts[0] == 'JP' && %w(HL IX IY).include?(parts[1])
    [bytes, combine_instr([parts[0], "(#{parts[1]})"])]
  else
    instr_pair
  end
end

instrs = Instructions.new
                     .enum_for
                     .select { |x| x[1] }
                     .map { |x| add_args(x) }
                     .map { |x| remove_a(x) }
                     .map { |x| jp_register_in_quotes(x) }
                     .to_a
                     .sort

def format_byte(b)
  case b
  when Numeric
    format '%02X', b
  when :xx
    'XX'
  end
end

instrs.each do |bytes, instr|
  puts format('%-12s %s', bytes.map { |b| format_byte(b) }.join(' '), instr)
end
