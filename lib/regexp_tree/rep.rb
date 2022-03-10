class RegexpTree
  class Rep < RegexpTree
    PRECEDENCE = 4

    def initialize(r, m=0, n=nil, greedy=true)
      @r = r
      @m = m
      @n = n
      @greedy = greedy
    end

    def case_insensitive?
      @r.case_insensitive?
    end

    def multiline_insensitive?
      @r.multiline_insensitive?
    end

    def downcase
      Rep.new(@r.downcase, @m, @n, @greedy)
    end

    def pretty_format(out)
      @r.parenthesize(Elt).pretty_format(out)
      case @m
      when 0
        case @n
        when 0
          out.text '{0}'
        when 1
          out.text '?'
        when nil
          out.text '*'
        else
          out.text "{#{@m},#{@n}}"
        end
      when 1
        case @n
        when 1
        when nil
          out.text '+'
        else
          out.text "{#{@m},#{@n}}"
        end
      else
        if @m == @n
          out.text "{#{@m}}"
        else
          out.text "{#{@m},#{@n}}"
        end
      end

      out.text '?' unless @greedy
    end
  end
end
