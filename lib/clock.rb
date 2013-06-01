class Clock
    attr_accessor :in, :out, :date, :author
    def initialize(type, date, auth)
        @in = (type == :in)
        @out = (type == :out)
        @date = date
        @author = auth
    end
end