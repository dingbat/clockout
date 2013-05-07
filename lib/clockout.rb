require 'grit'
require 'time'

class Commit
	attr_accessor :message, :minutes, :date, :diffs, :sha
end

RED = 31
YELLOW = 33
MAGENTA = 35
LIGHT_BLUE = 94
def colorize(str, color)
    "\e[0;#{color};49m#{str}\e[0m"
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
		blocks = []
		block = []

		total_diffs, total_mins = 0, 0

		prev = nil
		commits.each do |commit|

			c = Commit.new
			c.date = commit.committed_date
			c.message = commit.message.gsub("\n",' ')
			c.diffs = diffs(commit)
			c.sha = commit.id[0..7]

			if block.size > 0
				last_date = block.last.date

				@clockins.each do |clockin|
					if clockin > last_date && clockin < c.date
						last_date = clockin
						@clockins.delete(clockin)
						break
					end
				end

				time_since_last = (last_date - commit.committed_date).abs/60
				
				if (time_since_last > $opts[:time_cutoff])
					blocks << block
					block = []
				else
					c.minutes = time_since_last

	                @time_per_day[c.date.strftime(DAY_FORMAT)] += c.minutes

					total_diffs += c.diffs
					total_mins += c.minutes
				end
			end

			block << c
		end

		blocks << block

		# Now go through each block's first commit and estimate the time it took
		blocks.each do |block|
			first = block.first

	        # See if they were overriden in the .clock file
	        if ($opts[first.sha.to_sym])
	            first.minutes = $opts[first.sha.to_sym].to_i
			elsif ($opts[:ignore_initial] && block == blocks.first) || total_diffs == 0
				first.minutes = 0
			else
				first.minutes = $opts[:estimation_factor]*first.diffs*(1.0*total_mins/total_diffs)
			end

	        @time_per_day[first.date.strftime(DAY_FORMAT)] += first.minutes
		end
	end

	def print_chart(condensed)
		cols = (condensed ? 30 : COLS)
		total_sum = 0
		current_day = nil
		@blocks.each do |block|
			date = block.first.date.strftime(DAY_FORMAT)
			if date != current_day
				puts if (!condensed)

				current_day = date

				sum = @time_per_day[date]
				total_sum += sum

				sum_str = "#{(sum/60.0).round(2)} hrs"
				print colorize(date,MAGENTA)
				print colorize("."*(cols - date.length - sum_str.length),MAGENTA)
				print colorize(sum_str,RED)
				puts
			end

			print_timeline(block) if (!condensed)
		end

		puts " "*(cols-10) + colorize("-"*10,MAGENTA)
		sum_str = "#{(total_sum/60.0).round(2)} hrs"
		puts " "*(cols-sum_str.length) + colorize(sum_str,RED)
	end

	def print_timeline(block)
		# subtract from the time it took for first commit
		time = (block.first.date - block.first.minutes*60).strftime('%l:%M %p')+":  "
		print colorize(time,YELLOW)

		char_count = time.length

		block.each do |commit|
			if commit.minutes < 60
				c_mins = "#{commit.minutes.round(0)}m"
			else
				c_mins = "#{(commit.minutes/60.0).round(1)}h"
			end

			seperator = " | "
		
			add = c_mins.length+seperator.length
			if char_count + add > COLS-5
				puts
				char_count = time.length # indent by the length of the time label on left
				print " "*char_count
			end

			char_count += add

			print c_mins+colorize(seperator,RED)
		end
		puts
	end

	def print_estimations
		sum = 0
		@blocks.each do |block|
			first = block.first
			date = first.date.strftime('%b %e')+": "
			sha = first.sha+" "
			if first.minutes < 60
				time = "#{first.minutes.round(0)} min"
			else
				time = "#{(first.minutes/60.0).round(2)} hrs"
			end

			print colorize(date,YELLOW)
			print colorize(sha,RED)

			cutoff = COLS-time.length-date.length-6-sha.length
			message = first.message[0..cutoff]
			message += "..." if first.message.length > cutoff
			print message

			print " "*(COLS-message.length-time.length-date.length-sha.length)
			puts colorize(time, LIGHT_BLUE)

			sum += first.minutes
		end

		puts " "*(COLS-10) + colorize("-"*10,LIGHT_BLUE)
		sum_str = "#{(sum/60.0).round(2)} hrs"
		puts " "*(COLS-sum_str.length) + colorize(sum_str, LIGHT_BLUE)
	end

	def get_repo(path)
	    begin
	        return Grit::Repo.new(path)
	    rescue Exception => e
	    	print colorize("Error: ", RED)
	        if e.class == Grit::NoSuchPathError
	            puts "Path '#{path}' could not be found."
	        else
	            puts "'#{path}' is not a Git repository."
	        end
	    end
	end

	def self.parse_clockfile(file)
	    return nil if !File.exists?(file)

	    opts = {}

	    line_num = 0
	    File.foreach(file) do |line|
	        line_num += 1
	        #Strip whitespace
	        line.strip!
	        #Strip comments
	        line = line.split(";",2)[0]

	        next if !line || line.length == 0

	        sides = line.split("=",2)

	        clock_split = sides[0].split(" ",2)
	        if (clock_split[0] == "in" || clock_split[0] == "out")

	        	begin
	        		date = Time.parse(clock_split[1])
	        	rescue Exception => e
	        		puts "#{colorize("Error:", RED)} invalid date for '#{clock_split[0]}' on line #{line_num} of .clock file:"
	        		puts "    #{line}"

	        		exit
	        	end

	        	key = (clock_split[0] == "out") ? :clockouts : :clockins

        		opts[key] ||= []
        		opts[key] << date
	        else
		        if sides.length != 2
		            puts "#{colorize("Error:", RED)} bad syntax on line #{line_num} of .clock file:"
		            puts "    #{line}"
		            puts ""
		            puts "Line must be of form:"
		            puts "    KEY = VALUE"

		            exit
		        end

		        left = sides[0].strip
		        right = sides[1].strip

		        if left == "ignore_initial"
		            right = (right != "0")
		        elsif left == "time_cutoff"
		            right = right.to_i
		        elsif left == "estimation_factor"
		        	right = right.to_f
		        end

		        opts[left.to_sym] = right
		    end
	    end

	    opts 
	end

	def self.clock_path(path)
		path+"/.clock"
	end

	def initialize(path)
		# Default options
		$opts = {time_cutoff:120, my_files:"/.*/", estimation_factor:0.9}

		# Parse .clock options
	    clock_opts = Clockout.parse_clockfile(Clockout.clock_path(path))

	    if clock_opts
		    @clockins = clock_opts[:clockins] || []
		    @clockouts = clock_opts[:clockouts] || []

			# Merge with .clock override options
		    $opts.merge!(clock_opts)
		end

		repo = get_repo(path) || exit

		commits = repo.commits('master', 500)
		commits.reverse!

		@time_per_day = Hash.new(0)
		@blocks = seperate_into_blocks(repo, commits)
	end
end
