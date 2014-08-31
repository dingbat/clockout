require 'rugged'
require 'yaml'

require 'printer'
require 'record'

COLS = 80
DAY_FORMAT = '%B %e, %Y'

class Clockout
    attr_accessor :blocks, :time_per_day, :maxed_out

    def commits_to_records(git_commits)
        git_commits.each_with_index.map do |commit, i| 
            Commit.new(commit)
        end
    end

    def clocks_to_records(clocks, in_out)
        clocks.map do |c| 
            Clock.new(in_out, c.first[0], c.first[1])
        end
    end

    def try_overriding_record(record)
        overrides = $opts[:overrides]
        overrides.each do |k, v|
            if record.sha.start_with? k
                record.minutes = v
                record.overriden = true
                return true
            end
        end if overrides

        false
    end

    def run(data)
        blocks = []
        total_diffs, total_mins = 0, 0

        add_commit = lambda do |commit|
            last = blocks.last
            mins = (last && last.last.minutes) ? last.last.minutes*60 : 0
            if !last || (commit.date - (last.last.date + mins))/60.0 > $opts[:time_cutoff]
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
                if !try_overriding_record(curr_c)
                    # Otherwise, if we're ignoring initial & it's initial, set minutes to 0
                    if $opts[:ignore_initial] && !prev_c
                        curr_c.minutes = 0
                    else
                        curr_c.clocked_in = true if prev_c && prev_c.class == Clock && prev_c.in
                        # If it added successfully into a block (or was clocked in), we can calculate based on last commit
                        if add_commit.call(curr_c) || curr_c.clocked_in
                            curr_c.minutes = (curr_c.date - prev_c.date)/60.0 # clock or commit, doesn't matter
                        end
                        # Otherwise, we'll do an estimation later, once we have more data
                    end
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
                    first.minutes = first.addition
                else
                    first.minutes = first.diffs/diffs_per_min * $opts[:estimation_factor] + first.addition
                end
                add_time_to_day.call(first.minutes, first.date)
            end
        end
        
        blocks
    end

    def prepare_blocks(commits_in, author)
        clockins = $opts[:in] || {}
        clockouts = $opts[:out] || {}

        # Convert clock-in/-outs into Clock objs & commits into Commit objs
        clocks = clocks_to_records(clockins, :in) + clocks_to_records(clockouts, :out)
        commits = commits_to_records(commits_in)

        # Merge & sort everything by date
        data = (commits + clocks).sort { |a,b| a.date <=> b.date }

        # If author is specified, delete everything not by that author
        data.delete_if { |c| c.author != author } if author

        @blocks = run(data)
    end

    def last
        @blocks.last.last
    end

    def self.get_repo(path)
        repo = Rugged::Repository.discover(path)
        return repo, repo.workdir
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
        return nil if !path
        File.join(path,"clock.yml")
    end

    def self.root_path(path)
        repo, root_path = get_repo(path)
        root_path
    end

    def get_commits(repo, num)
        walker = Rugged::Walker.new(repo)
        walker.push(repo.head.target_id)
        walker.each.take(num)
    end

    def initialize(path = nil, author = nil, num = 1)
        @time_per_day = Hash.new(0)

        # Default options
        $opts = {time_cutoff:120, estimation_factor:1.0}

        if path
            repo, root_path = Clockout.get_repo(path) || exit

            # Parse config options
            clock_opts = Clockout.parse_clockfile(Clockout.clock_path(root_path))

            # Merge with config override options
            $opts.merge!(clock_opts) if clock_opts

            commits = get_commits(repo, num)

            @maxed_out = (commits.size == num)
    
            prepare_blocks(commits, author)
        end
    end
end
