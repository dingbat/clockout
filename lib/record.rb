class Record
    attr_accessor :date, :author
end

class Commit < Record
    # From Grit::Commit object
    attr_accessor :message, :stats, :diffs, :sha
    # Time calc
    attr_accessor :minutes, :addition, :overriden, :estimated
    # Whether it's been padded by a clock in/out
    attr_accessor :clocked_in, :clocked_out
    
    def initialize(commit = nil, date = nil)
        @addition = 0
        @date = date
        if commit
            @author = commit.author.email
            @date = commit.committed_date
            @message = commit.message.gsub("\n",' ')
            @sha = commit.id
        end
    end

    def calculate_diffs(my_files, not_my_files)
        return @diffs if @diffs

        plus, minus = 0, 0

        @stats.to_diffstat.each do |diff_stat|
            should_include = (diff_stat.filename =~ my_files)
            should_ignore = not_my_files && (diff_stat.filename =~ not_my_files)
            if should_include && !should_ignore
                plus += diff_stat.additions
                minus += diff_stat.deletions
            end
        end

        # Weight deletions half as much, since they are typically
        # faster to do & also are 1:1 with additions when changing a line
        @diffs = plus+minus/2
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
