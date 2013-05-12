require 'grit'
require 'time'
require 'yaml'

class Commit
	attr_accessor :message, :minutes, :date, :diffs, :sha, :clocked_in, :clocked_out
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
	COLS = 80
	DAY_FORMAT = '%B %e, %Y'

	attr_accessor :blocks

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

	def seperate_into_blocks(repo, commits)
		return [] if commits.empty?

		blocks = []
		block = []

		total_diffs, total_mins = 0, 0

		last_date = nil
		commits.each do |commit|

			c = Commit.new
			c.date = commit.committed_date
			c.message = commit.message.gsub("\n",' ')
			c.diffs = diffs(commit)
			c.sha = commit.id[0..7]

			# See if this commit was overriden in the config file
	        overrides = $opts[:overrides]
	        overrides.each do |k, v|
        		if commit.id.start_with? k
        			c.minutes = v
        			break
        		end
        	end if overrides

        	clockins = $opts[:in]
        	clockins.each do |cin|
        		if (!last_date || cin > last_date) && cin < c.date
        			last_date = cin
        			c.clocked_in = true
        		end
        	end if clockins

			if last_date
				time_since_last = (last_date - commit.committed_date).abs/60
				
				if (time_since_last > $opts[:time_cutoff])
					blocks << block
					block = []
				else
					c.minutes = time_since_last if !c.minutes

	                @time_per_day[c.date.strftime(DAY_FORMAT)] += c.minutes

					total_diffs += c.diffs
					total_mins += c.minutes
				end
			end

			last_date = c.date

			block << c
		end

		blocks << block

		# Now go through each block's first commit and estimate the time it took
		blocks.each do |block|
			first = block.first

        	# If minutes haven't been already set, try estimating it
        	if (!first.minutes)
				if ($opts[:ignore_initial] && block == blocks.first) || total_diffs == 0
					first.minutes = 0
				else
					diff_min_ratio = (1.0*total_mins/total_diffs)
					first.minutes = $opts[:estimation_factor]*first.diffs*diff_min_ratio
				end
			end

	        @time_per_day[first.date.strftime(DAY_FORMAT)] += first.minutes
		end
	end

	def print_chart(condensed)
		cols = condensed ? 30 : COLS
		total_sum = 0
		current_day = nil
		@blocks.each do |block|
			date = block.first.date.strftime(DAY_FORMAT)
			if date != current_day
				puts if (!condensed)

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

			print c_mins+seperator.red
		end
		puts
	end

	def print_estimations
		sum = 0
		@blocks.each do |block|
			first = block.first
			date = first.date.strftime('%b %e')+":"
			sha = first.sha
			time = first.minutes.as_time

			puts align({date => :yellow, sha => :red, first.message => :to_s, time => :light_blue})

			sum += first.minutes
		end

		puts align({"-"*10 => :light_blue})
		puts align({sum.as_time(:hours) => :light_blue})
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

	def initialize(path)
		repo, root_path = Clockout.get_repo(path) || exit

		# Default options
		$opts = {time_cutoff:120, my_files:"/.*/", estimation_factor:1.0}

		# Parse config options
	    clock_opts = Clockout.parse_clockfile(Clockout.clock_path(root_path))

	    if clock_opts
			# Merge with config override options
		    $opts.merge!(clock_opts)
		end

		p $opts

		commits = repo.commits('master', 500)
		commits.reverse!

		@time_per_day = Hash.new(0)
		@blocks = seperate_into_blocks(repo, commits)
	end
end
