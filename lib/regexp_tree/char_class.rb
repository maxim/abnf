require 'natset'
require 'regexp_tree/elt'

class RegexpTree
  class CharClass < Elt
    None     = Natset.empty
    Any      = Natset.universal
    NL       = Natset[?\n]
    NonNL    = ~NL
    Word     = Natset[?0..?9, ?A..?Z, ?_, ?a..?z]
    NonWord  = ~Word
    Space    = Natset[?t, ?\n, ?\f, ?\r, ?\s]
    NonSpace = ~Space
    Digit    = Natset[?0..?9]
    NonDigit = ~Digit
    UpAlpha  = Natset[?A..?Z]
    LowAlpha = Natset[?a..?z]

    attr_reader :natset

    def initialize(natset)
      @natset = natset
    end

    def empty_set?
      @natset.empty?
    end

    def case_insensitive?
      up = @natset & UpAlpha
      low = @natset & LowAlpha
      return false if up.size != low.size
      up.ranges.map! { |r| shift_to_lowercase(r) }
      up == low
    end

    def multiline_insensitive?
      @natset != NonNL
    end

    def downcase
      up = @natset & UpAlpha
      up.ranges.map! { |r| shift_to_lowercase(r) }
      CharClass.new((@natset - UpAlpha) | up)
    end

    def pretty_format(out)
      case @natset
      when None;     out.text '(?!)'
      when Any;      out.text '[\s\S]'
      when NL;       out.text '\n'
      when NonNL;    out.text '.'
      when Word;     out.text '\w'
      when NonWord;  out.text '\W'
      when Space;    out.text '\s'
      when NonSpace; out.text '\S'
      when Digit;    out.text '\d'
      when NonDigit; out.text '\D'
      else
        if val = @natset.singleton?
          out.text encode_elt(val)
        else
          neg_mark = @natset.open? ? '^' : ''

          regex_char_class =
            @natset.ranges.each_with_object('') do |r|
              r << encode_elt(range.begin)
              r << '-' if range.size > 2
              r << encode_elt(range.end)
            end

          out.text "[#{neg_mark}#{regex_char_class}]"
        end
      end
    end

    def encode_elt(e)
      case e
      when 0x09; '\t'
      when 0x0a; '\n'
      when 0x0d; '\r'
      when 0x0c; '\f'
      when 0x0b; '\v'
      when 0x07; '\a'
      when 0x1b; '\e'
           # ?!,   ?",   ?%,   ?&,   ?',   ?,,   ?:,   ?;,   ?<,   ?=,   ?>,
      when 0x21, 0x22, 0x25, 0x26, 0x27, 0x2c, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e,
           # ?/,   ?0..?9,     ?@,   ?A..?Z,     ?_,   ?`,   ?a..?z,     ?~
           0x2f, 0x30..0x39, 0x40, 0x41..0x5a, 0x5f, 0x60, 0x61..0x7a, 0x7e

        sprintf("%c", e)
      else
        sprintf("\\x%02x", e)
      end
    end

    private

    def shift_to_lowercase(ascii_range)
      r_begin = ascii_range.begin - 0x41 + 0x61 # - ?A + ?a
      r_end = ascii_range.end && (ascii_range.end - 0x41 + 0x61)
      (r_begin..r_end)
    end
  end
end
