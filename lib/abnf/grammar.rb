require 'abnf/elements/alt'
require 'abnf/elements/rep'
require 'abnf/elements/seq'
require 'abnf/elements/term'
require 'abnf/elements/var'

class ABNF
  EmptySet = Alt.new
  EmptySeq = Seq._new
end
