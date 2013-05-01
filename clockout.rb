#!/usr/bin/env ruby

require 'rubygems'
begin
	require 'grit'
rescue Exception => e
	puts "Couldn't find the `grit` gem on your system."
	puts "Please run `sudo gem install grit` and try again."
	exit
end

$cols = 80
$day_format = '%B %e, %Y'
$time_per_day = Hash.new(0)

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

	commits.each do |commit|

		c = Commit.new
		c.date = commit.committed_date
		c.message = commit.message.gsub("\n",' ')
		c.diffs = diffs(commit)
		c.sha = commit.id[0..7]

		if block.size > 0
			time_since_last = (block.last.date - commit.committed_date).abs/60
			
			if (time_since_last > $opts[:time_cutoff])
				blocks << block
				block = []
			else
				c.minutes = time_since_last

                $time_per_day[c.date.strftime($day_format)] += c.minutes

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
			# Underestimate by a factor of 0.9
			first.minutes = 0.9*first.diffs*(1.0*total_mins/total_diffs)
		end

        $time_per_day[first.date.strftime($day_format)] += first.minutes
	end
end

def print_chart(blocks)
	cols = ($opts[:condensed] ? 30 : $cols)
	total_sum = 0
	current_day = nil
	blocks.each do |block|
		date = block.first.date.strftime($day_format)
		if date != current_day
			puts if (!$opts[:condensed])

			current_day = date

			sum = $time_per_day[date]
			total_sum += sum

			sum_str = "#{(sum/60.0).round(2)} hrs"
			print colorize(date,MAGENTA)
			print colorize("."*(cols - date.length - sum_str.length),MAGENTA)
			print colorize(sum_str,RED)
			puts
		end

		print_timeline(block) if (!$opts[:condensed])
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
		if char_count + add > $cols-5
			puts
			char_count = time.length # indent by the length of the time label on left
			print " "*char_count
		end

		char_count += add

		print c_mins+colorize(seperator,RED)
	end
	puts
end

def print_estimations(blocks)
	sum = 0
	blocks.each do |block|
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

		cutoff = $cols-time.length-date.length-6-sha.length
		message = first.message[0..cutoff]
		message += "..." if first.message.length > cutoff
		print message

		print " "*($cols-message.length-time.length-date.length-sha.length)
		puts colorize(time, LIGHT_BLUE)

		sum += first.minutes
	end

	puts " "*($cols-10) + colorize("-"*10,LIGHT_BLUE)
	sum_str = "#{(sum/60.0).round(2)} hrs"
	puts " "*($cols-sum_str.length) + colorize(sum_str, LIGHT_BLUE)
end

def parse_options(args)
    opts = {}

	args.each do |arg|
		if (arg == "-h" || arg == "--help")
			opts[:help] = true
        elsif (arg == "-s" || arg == "--see-clock")
            opts[:see_clock] = true
		elsif (arg == "-e" || arg == "--estimations")
			opts[:estimations] = true
		elsif (arg == "-c" || arg == "--condensed")
			opts[:condensed] = true
		elsif (arg[0] == "-")
			puts "Error: invalid option '#{arg}'."
			puts "Try --help for help."
			exit
		end
	end

	opts
end

def get_repo(path)
    begin
        return Grit::Repo.new(path)
    rescue Exception => e
        if e.class == Grit::NoSuchPathError
            puts "Error: Path '#{path}' could not be found."
        else
            puts "Error: '#{path}' is not a Git repository."
        end
    end
end

def parse_clockfile(file)
    return nil if !File.exists?(file)

    opts = {}

    line_num = 0
    File.foreach(file) do |line|
        line_num += 1
        line.strip!

        next if line[0] == ";" || line.length == 0

        sides = line.split("=",2)

        if sides.length != 2
            puts "Error: bad syntax on line #{line_num} of .clock file:"
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
        end

        opts[left.to_sym] = right
    end

    opts
end

def prepare_options
    opts = {time_cutoff:120, my_files:"/.*/"} # defaults
    opts.merge!(parse_options(ARGV))

    if opts[:help]
        banner = <<-EOS
Clockout v0.1
Usage:
        ./clockout.rb [options] <path to git repo>

Options:
    --estimations, -e:   Show estimations made for first commit of each block
      --condensed, -c:   Condense output (don't show the timeline for each day)
      --see-clock, -s:   See options specified in .clock file
           --help, -h:   Show this message
EOS
        puts banner
        exit
    end

    path = ARGV[0] || nil
    if (!path)
        puts "Error: Git repo path must be specified."
        puts "Usage:"
        puts "        ./clockout.rb [options] <path to git repo>"
        exit
    end

    opts[:path] = path

    clock_path = File.expand_path(path)+"/.clock"
    clock_opts = parse_clockfile(clock_path)

    if opts[:see_clock]
        if !clock_opts
            puts "No .clock file found at '#{clock_path}'."
        else
            puts "Clock options:"
            clock_opts.each do |k, v|
                key = k[0..19]
                puts "    #{key}:#{' '*(20-key.length)}#{v}"
            end
        end
        exit
    end

    opts.merge!(clock_opts) if clock_opts
    opts
end

$opts = prepare_options
repo = get_repo($opts[:path]) || exit
	
commits = repo.commits('master', 500)
commits.reverse!

blocks = seperate_into_blocks(repo, commits)

if ($opts[:estimations])
	print_estimations(blocks)
else
	print_chart(blocks)
end
