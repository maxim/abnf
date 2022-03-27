# RFC 2234
class Parser
rule
  rulelist: { result = nil }
  | rulelist rule
    {name = val[1][0]
    rhs = val[1][1]
    @grammar.merge(name => rhs)
    result ||= name}

  rule: defname assign alt {result = [val[0], val[2]]}

  alt: seq
  | alt altop seq {result = val[0] | val[2]}

  seq: rep
  | seq rep {result = val[0] + val[1]}

  rep: element
  | repeat element {result = val[1].rep(*val[0])}

  repeat: repop {result = [0, nil]}
  | repop int {result = [0, val[1]]}
  | int {result = [val[0], val[0]]}
  | int repop {result = [val[0], nil]}
  | int repop int {result = [val[0], val[2]]}

  element: name {result = Var.new(val[0])}
  | lparen alt rparen {result = val[1]}
  | lbracket alt rbracket {result = val[1].rep(0, 1)}
  | val
end

---- header
class ABNF
---- inner
  ScanError = Class.new(StandardError)

  def initialize(grammar)
    @grammar = grammar
  end

  def parse(input)
    @input = input
    yyparse self, :scan
  end

  def scan
    prev = nil
    scan1 do |toktype, tokval|
      if prev
        if prev[0] == :name && toktype == :assign
          yield [:defname, prev[1]]
        else
          yield prev
        end
      end
      prev = [toktype, tokval]
    end
    yield prev
  end

  def scan1
    @input.each_line do |line|
      until line.empty?
        case line
        when /\A[ \t\r\n]+/
          t = $&
        when /\A;/
          t = line
        when /\A[A-Za-z][A-Za-z0-9\-_]*/ # _ is not permitted by ABNF
          yield :name, (t = $&).downcase.intern
        when /\A=\/?/
          yield :assign, (t = $&) # | is not permitted by ABNF
        when /\A[\/|]/
          yield :altop, (t = $&)
        when /\A\*/
          yield :repop, (t = $&)
        when /\A\(/
          yield :lparen, (t = $&)
        when /\A\)/
          yield :rparen, (t = $&)
        when /\A\[/
          yield :lbracket, (t = $&)
        when /\A\]/
          yield :rbracket, (t = $&)
        when /\A\d+/
          yield :int, (t = $&).to_i
        when /\A"([ !#-~]*)"/
          es = []
          (t = $&)[1...-1].each_byte {|b|
            case b
            when 0x41..0x5a # ?A..?Z
              b2 = b - 0x41 + 0x61 # ?A + ?a
              es << Term.new(Natset.new(b, b2))
            when 0x61..0x7a # ?a..?z
              b2 = b - 0x61 + 0x41 # ?a + ?A
              es << Term.new(Natset.new(b, b2))
            else
              es << Term.new(Natset.new(b))
            end
          }
          yield :val, Seq[*es]
        when /\A%b([01]+)-([01]+)/
          t = $&
          yield :val, Term.new(Natset.new($1.to_i(2)..$2.to_i(2)))
        when /\A%b[01]+(?:\.[01]+)*/
          es = []
          (t = $&).scan(/[0-1]+/) {|v|
            es << Term.new(Natset.new(v.to_i(2)))
          }
          yield :val, Seq[*es]
        when /\A%d([0-9]+)-([0-9]+)/
          t = $&
          yield :val, Term.new(Natset.new($1.to_i..$2.to_i))
        when /\A%d[0-9]+(?:\.[0-9]+)*/
          es = []
          (t = $&).scan(/[0-9]+/) {|v|
            es << Term.new(Natset.new(v.to_i))
          }
          yield :val, Seq[*es]
        when /\A%x([0-9A-Fa-f]+)-([0-9A-Fa-f]+)/
          t = $&
          yield :val, Term.new(Natset.new($1.hex..$2.hex))
        when /\A%x[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]+)*/
          es = []
          (t = $&).scan(/[0-9A-Fa-f]+/) {|v|
            es << Term.new(Natset.new(v.hex))
          }
          yield :val, Seq[*es]
        when /\A<([\x20-\x3D\x3F-\x7E]*)>/
          # Using angle brackets (i.e. <rulename>) is a way to refer to ABNF
          # rules in regular written text. It's called "prose-val". The angle
          # brackets are normally also accepted on the left side of the rule
          # assignment, but this parser does not support them, whether in prose,
          # or in rule lists.
          raise ScanError.new("prose-val is not supported: #{$&}")
        else
          raise ScanError.new(line)
        end
        line[0, t.length] = ''
      end
    end

    yield false, false
  end
---- footer
end
