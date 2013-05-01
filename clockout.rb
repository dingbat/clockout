#!/usr/bin/env ruby

require 'rubygems'
begin
	require 'grit'
	require 'colorize'
rescue Exception => e
	puts "Couldn't find one or more of gems 'grit', or `colorize` on your system."
	puts "Please run `sudo gem install grit colorize` and try again."
	exit
end

$cols = 80

class Commit
	attr_accessor :message, :minutes, :date, :diffs, :sha
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
		c.sha = commit.id

		if block.size > 0
			time_since_last = (block.last.date - commit.committed_date).abs/60
			
			if (time_since_last > $opts[:time_cutoff])
				blocks << block
				block = []
			else
				c.minutes = time_since_last

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
		if ($opts[:ignore_initial] && block == blocks.first) || total_diffs == 0
			first.minutes = 0
		else
			# Underestimate by a factor of 0.9
			first.minutes = 0.9*first.diffs*(1.0*total_mins/total_diffs)
		end
	end
end

def print_chart(blocks)
	cols = ($opts[:condensed] ? 30 : $cols)
	total_sum = 0
	current_day = nil
	blocks.each do |block|
		format = '%B %e, %Y'
		date = block.first.date.strftime(format)
		if date != current_day
			puts if (!$opts[:condensed])

			current_day = date

			sum = 0
			blocks.each do |block|
				d = block.first.date.strftime(format)
				next if d != current_day
				block.each do |c|
					sum += c.minutes
				end
			end
			total_sum += sum

			sum_str = "#{(sum/60.0).round(2)} hrs"
			print date.magenta
			print ("."*(cols - date.length - sum_str.length)).magenta
			print sum_str.red
			puts
		end

		print_timeline(block) if (!$opts[:condensed])
	end

	puts " "*(cols-10) + ("-"*10).magenta
	sum_str = "#{(total_sum/60.0).round(2)} hrs"
	puts " "*(cols-sum_str.length) + sum_str.red
end

def print_timeline(block)
	# subtract from the time it took for first commit
	time = (block.first.date - block.first.minutes*60).strftime('%l:%M %p')+":  "
	print time.yellow

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

		print c_mins+seperator.red
	end
	puts
end

def print_estimations(blocks)
	sum = 0
	blocks.each do |block|
		first = block.first
		date = first.date.strftime('%b %e')+": "
		sha = first.sha[0..7]+" "
		if first.minutes < 60
			time = "#{first.minutes.round(0)} min"
		else
			time = "#{(first.minutes/60.0).round(2)} hrs"
		end

		print date.yellow
		print sha.red

		cutoff = $cols-time.length-date.length-6-sha.length
		message = first.message[0..cutoff]
		message += "..." if first.message.length > cutoff
		print message

		print " "*($cols-message.length-time.length-date.length-sha.length)
		puts time.light_blue

		sum += first.minutes
	end

	puts " "*($cols-10) + ("-"*10).light_blue
	sum_str = "#{(sum/60.0).round(2)} hrs"
	puts " "*($cols-sum_str.length) + sum_str.light_blue
end

def parse_options(args)
    opts = {}

	args.each do |arg|
		if (arg == "-h" || arg == "--help")
			opts[:help] = true
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
    opts = {}

    File.foreach(file) do |line|
        line.strip!

        next if line[0] == ";" || line.length == 0

        sides = line.split("=")
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

# defaults
$opts = {time_cutoff:120, my_files:"/.*/"}
$opts.merge!(parse_options(ARGV))

if $opts[:help]
	banner = <<-EOS
Clockout v0.1
Usage:
        ./clockout.rb [options] <path to git repo>

Options:
    --estimations, -e:   Show estimations made for first commit of each block
      --condensed, -c:   Condense output (don't show the timeline for each day)
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

clock_path = File.expand_path(path)+"/.clock"
$opts.merge!(parse_clockfile(clock_path)) if File.exists?(clock_path)

repo = get_repo(path) || exit
	
commits = repo.commits('master', 500)
commits.reverse!

blocks = seperate_into_blocks(repo, commits)

if ($opts[:estimations])
	print_estimations(blocks)
else
	print_chart(blocks)
end
