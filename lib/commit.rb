class Commit
    attr_accessor :message, :minutes, :date, :diffs, :sha, :clocked_in, :clocked_out, :stats, :addition, :overriden, :author, :estimated
    
    def initialize(commit = nil)
        @addition = 0
        if commit
            @author = commit.author.email
            @date = commit.committed_date
            @message = commit.message.gsub("\n",' ')
            @sha = commit.id
            @stats = commit.stats
        end
    end

    def calculate_diffs(my_files, not_my_files)
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