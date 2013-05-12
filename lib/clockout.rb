require 'grit'
require 'time'
require 'yaml'

COLS = 80
DAY_FORMAT = '%B %e, %Y'

class Commit
    attr_accessor :message, :minutes, :date, :diffs, :sha, :clocked_in, :clocked_out, :addition, :overriden, :author, :estimated
    def initialize(commit = nil)
        @addition = 0
        if commit
            @author = commit.author.email
            @date = commit.committed_date
            @message = commit.message.gsub("\n",' ')
            @sha = commit.id
        end
    end
end

class Clock
    attr_accessor :in, :out, :date, :author
    def initialize(type, date, auth)
        @in = (type == :in)
        @out = (type == :out)
        @date = date
        @author = auth
    end
end

def puts_error(str)
    puts "Error: ".red + str
end

def align(strings, cols = COLS, sep = " ")
    ret = ""
    size = 0
    strings.each do |string, method|
        ultimate = (string == strings.keys[-1])
        penultimate = (string == strings.keys[-2])

        out = string
        out += " " unless (ultimate || penultimate)

        if ultimate
            # Add seperator
            cols_left = cols - size - out.length
            ret += sep*cols_left if cols_left > 0
        elsif penultimate
            last = strings.keys.last.length
            max_len = cols - size - last - 1
            if string.length > max_len
                # Truncate
                out = string[0..max_len-5].strip + "... "
            end
        end

        # Apply color & print
        ret += method.to_proc.call(out)

        size += out.length
    end

    ret
end

class String
    def colorize(color)
        "\e[0;#{color};49m#{self}\e[0m"
    end

    def red() colorize(31) end
    def yellow() colorize(33) end
    def magenta() colorize(35) end
    def light_blue() colorize(94) end
end

class Numeric
    def as_time(type = nil, min_s = " min", hr_s = " hrs")
        type = (self < 60) ? :minutes : :hours if !type
        if type == :minutes
            "#{self.round(0)}#{min_s}"
        else
            "#{(self/60.0).round(2)}#{hr_s}"
        end
    end
end

class Clockout
    def diffs(commit)
        plus, minus = 0, 0

        commit.stats.to_diffstat.each do |diff_stat|
            my_files = $opts[:my_files]
            not_my_files = $opts[:not_my_files]
            should_include = (diff_stat.filename =~ eval(my_files))
            should_ignore = not_my_files && (diff_stat.filename =~ eval(not_my_files))
            if should_include && !should_ignore
                plus += diff_stat.additions
                minus += diff_stat.deletions
            end
        end

        # Weight deletions half as much, since they are typically
        # faster to do & also are 1:1 with additions when changing a line
        plus+minus/2
    end

    def prepare_data(commits_in, author)
        clockins = $opts[:in] || {}
        clockouts = $opts[:out] || {}

        # Convert clock-in/-outs into Clock objs & commits into Commit objs
        clocks = []
        clockins.each { |c| clocks << Clock.new(:in, c.first[0], c.first[1]) }
        clockouts.each { |c| clocks << Clock.new(:out, c.first[0], c.first[1]) }
        commits_in.map! do |commit| 
            c = Commit.new(commit) 
            c.diffs = diffs(commit)
            c
        end

        # Merge & sort everything by date
        data = (commits_in + clocks).sort { |a,b| a.date <=> b.date }

        # If author is specified, delete everything not by that author
        data.delete_if { |c| c.author != author } if author

        blocks = []
        total_diffs, total_mins = 0, 0

        add_commit = lambda do |commit|
            last = blocks.last
            if !last || (commit.date - last.last.date)/60.0 > $opts[:time_cutoff]
                blocks << [commit]
                false
            else
                last << commit
                true
            end
        end

        add_time_to_day = lambda do |time, date|
            @time_per_day[date.strftime(DAY_FORMAT)] += time
        end

        # Now go through and coalesce Clocks into Commits, while also splitting into blocks
        i = 0
        while i < data.size
            prev_c = (i == 0) ? nil : data[i-1]
            next_c = data[i+1]
            curr_c = data[i]

            if curr_c.class == Clock
                # If next is also a clock and it's the same type, delete this & use that one instead
                if next_c && next_c.class == Clock && next_c.in == curr_c.in
                    data.delete_at(i)
                    next
                end

                # Clock in doesn't do anything, a commit will pick them up
                # For a clock out...
                if curr_c.out && prev_c
                    # If previous is an IN, delete both and make a new commit
                    if prev_c.class == Clock && prev_c.in
                        c = Commit.new
                        c.date = curr_c.date # date is "commit date", so on clockout
                        c.minutes = (curr_c.date - prev_c.date)/60.0
                        c.clocked_in, c.clocked_out = true, true

                        data.insert(i, c)
                        data.delete(prev_c)
                        data.delete(curr_c)

                        add_commit.call(c)
                        add_time_to_day.call(c.minutes, c.date)

                        #i is already incremented (we deleted 2 & added 1)
                        next
                    elsif !prev_c.overriden
                        #Otherwise, append time onto the last commit (if it's time wasn't overriden)
                        addition = (curr_c.date - prev_c.date)/60.0
                        if prev_c.minutes
                            prev_c.minutes += addition
                            add_time_to_day.call(addition, prev_c.date)
                        else
                            # This means it's an estimation commit (first one)
                            # Mark how much we shoul add after we've estimated
                            prev_c.addition = addition
                        end
                        prev_c.clocked_out = true
                    end
                end
            else
                # See if this commit was overriden in the config file
                overrides = $opts[:overrides]
                overrides.each do |k, v|
                    if curr_c.sha.start_with? k
                        curr_c.minutes = v
                        curr_c.overriden = true
                        break
                    end
                end if overrides

                if !curr_c.overriden && prev_c
                    curr_c.clocked_in = true if prev_c.class == Clock && prev_c.in
                    # If it added successfully into a block (or was clocked in), we can calculate based on last commit
                    if add_commit.call(curr_c) || curr_c.clocked_in
                        curr_c.minutes = (curr_c.date - prev_c.date)/60.0 # clock or commit, doesn't matter
                    end
                    # Otherwise, we'll do an estimation later, once we have more data
                end

                if curr_c.minutes
                    add_time_to_day.call(curr_c.minutes, curr_c.date)

                    if curr_c.diffs
                        total_diffs += curr_c.diffs
                        total_mins += curr_c.minutes
                    end
                end
            end

            i += 1
        end

        diffs_per_min = (1.0*total_diffs/total_mins)

        # Do estimation for all `nil` minutes.
        blocks.each do |block|
            first = block.first
            if !first.minutes
                first.estimated = true
                if diffs_per_min.nan? || diffs_per_min.infinite?
                    first.minutes = 0
                else
                    first.minutes = first.diffs/diffs_per_min * $opts[:estimation_factor] + first.addition
                end
                add_time_to_day.call(first.minutes, first.date)
            end
        end
        
        blocks
    end

    def print_chart(condensed)
        cols = condensed ? 30 : COLS
        total_sum = 0
        current_day = nil
        @blocks.each do |block|
            date = block.first.date.strftime(DAY_FORMAT)
            if date != current_day
                puts if (!condensed && current_day)

                current_day = date

                sum = @time_per_day[date]
                total_sum += sum

                puts align({date => :magenta, sum.as_time(:hours) => :red}, cols, ".".magenta)
            end

            print_timeline(block) if (!condensed)
        end

        puts align({"-"*10 => :magenta}, cols)
        puts align({total_sum.as_time(:hours) => :red}, cols)
    end

    def print_timeline(block)
        # subtract from the time it took for first commit
        time = (block.first.date - block.first.minutes*60).strftime('%l:%M %p')+":  "
        print time.yellow

        char_count = time.length

        block.each do |commit|
            c_mins = commit.minutes.as_time(nil, "m", "h")
            c_mins = "*#{c_mins}" if commit.clocked_in
            c_mins += "*" if commit.clocked_out

            seperator = " | "
        
            add = c_mins.length+seperator.length
            if char_count + add > COLS-5
                puts
                char_count = time.length # indent by the length of the time label on left
                print " "*char_count
            end

            char_count += add

            # Blue for clockin/out commits
            print c_mins+(commit.message ? seperator.red : seperator.light_blue)
        end
        puts
    end

    def print_estimations
        sum = 0
        estimations = []
        @blocks.each do |block|
            estimations << block.first if block.first.estimated
        end

        if estimations.empty?
            puts "No estimations made."
        else
            estimations.each do |c|
                date = c.date.strftime('%b %e')+":"
                sha = c.sha[0..7]
                time = c.minutes.as_time

                puts align({date => :yellow, sha => :red, c.message => :to_s, time => :light_blue})

                sum += c.minutes
            end

            puts align({"-"*10 => :light_blue})
            puts align({sum.as_time(:hours) => :light_blue})
        end
    end

    def self.get_repo(path, original_path = nil)
        begin
            return Grit::Repo.new(path), path
        rescue Exception => e
            if e.class == Grit::NoSuchPathError
                puts_error "Path '#{path}' could not be found."
                return nil
            else
                # Must have drilled down to /
                if (path.length <= 1)
                    puts_error "'#{original_path}' is not a Git repository."
                    return nil
                end

                # Could be that we're in a directory inside the repo
                # Strip off last directory
                one_up = path
                while ((one_up = one_up[0..-2])[-1] != '/') do end

                # Recursively try one level higher
                return get_repo(one_up[0..-2], path)
            end
        end
    end

    def self.parse_clockfile(file)
        return nil if !File.exists?(file)

        begin
            opts = YAML.load_file(file)
        rescue Exception => e
            puts_error e.to_s
            exit
        end

        # Symbolizes keys
        Hash[opts.map{|k,v| [k.to_sym, v]}]
    end

    def self.clock_path(path)
        path+"/clock.yaml"
    end

    def self.root_path(path)
        repo, root_path = get_repo(path)
        root_path
    end

    def initialize(path, author = nil)
        repo, root_path = Clockout.get_repo(path) || exit

        # Default options
        $opts = {time_cutoff:120, my_files:"/.*/", estimation_factor:1.0}

        # Parse config options
        clock_opts = Clockout.parse_clockfile(Clockout.clock_path(root_path))

        # Merge with config override options
        $opts.merge!(clock_opts) if clock_opts

        commits = repo.commits('master', 500)
        commits.reverse!

        @time_per_day = Hash.new(0)
        @blocks = prepare_data(commits, author)
    end
end
