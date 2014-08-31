class Record
    attr_accessor :date, :author
end

class Commit < Record
    # From Grit::Commit object
    attr_accessor :message, :diffs, :sha
    # Time calc
    attr_accessor :minutes, :addition, :overriden, :estimated
    # Whether it's been padded by a clock in/out
    attr_accessor :clocked_in, :clocked_out
    
    def initialize(commit = nil, date = nil, paths = nil)
        @addition = 0
        @date = date
        if commit
            @author = commit.author[:email]
            @date = commit.time
            @message = commit.message.gsub("\n",' ')
            @sha = commit.oid
            @diffs = 0
            commit.diff(commit.parents[0]).each_patch do |patch|
                # Weight deletions half as much, since they are typically
                # faster to do & also are 1:1 with additions when changing a line
                @diffs += patch.stat[0] + patch.stat[1]/2
            end
        end
    end
end

class Clock < Record
    # Whether its in or out
    attr_accessor :in, :out
    def initialize(type, date, auth)
        @in = (type == :in)
        @out = (type == :out)
        @date = date
        @author = auth
    end
end
