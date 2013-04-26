#!/usr/bin/env ruby

require 'rubygems'
require 'grit'
require 'colorize'
require 'trollop'

$cols = 90

class Commit
	attr_accessor :message, :minutes, :date, :diffs
end

def diffs(commit)
	plus, minus = 0, 0

	commit.stats.to_diffstat.each do |diff_stat|
		should_include = (diff_stat.filename =~ /#{$opts[:include_diffs]}/)
		should_ignore = (diff_stat.filename =~ /#{$opts[:ignore_diffs]}/) && $opts[:ignore_diffs]
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
		c.message = commit.message[0..70].gsub("\n",' ')
		c.message += "..." if commit.message.length > 70
		c.diffs = diffs(commit)

		if block.size > 0
			time_since_last = (block.last.date - commit.committed_date).abs/60
			
			if (time_since_last > $opts[:time]) #new block cutoff at 2 hrs
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
		if $opts[:ignore_initial] && block == blocks.first
			first.minutes = 0
		else
			# Underestimate by a factor of 0.9
			first.minutes = 0.9*first.diffs*(1.0*total_mins/total_diffs)
		end
	end
end

def print_chart(blocks)
	total_sum = 0
	current_day = nil
	blocks.each do |block|
		date = block.first.date.strftime('%B %e, %Y')
		if date != current_day
			current_day = date

			sum = 0
			blocks.each do |block|
				d = block.first.date.strftime('%B %e, %Y')
				next if d != current_day
				block.each do |c|
					sum += c.minutes
				end
			end
			total_sum += sum

			sum_str = "#{(sum/60.0).round(2)} hrs"
			puts
			print date.magenta
			print ("."*($cols - date.length - sum_str.length)).magenta
			print sum_str.red
			puts
		end

		print_timeline(block)
	end

	puts " "*($cols-10) + ("-"*10).magenta
	sum_str = "#{(total_sum/60.0).round(2)} hrs"
	puts " "*($cols-sum_str.length) + sum_str.red
end

def print_timeline(block)
	time = block.first.date.strftime('%l:%M %p')+":  "
	print time.yellow

	block.each do |commit|
		if commit.minutes < 60
			c_mins = "#{commit.minutes.round(0)}m"
		else
			c_mins = "#{(commit.minutes/60.0).round(1)}h"
		end
		print c_mins+" | ".red
	end
	puts
end

def print_estimations(blocks)
	sum = 0
	blocks.each do |block|
		first = block.first
		date = first.date.strftime('%b %e')+": "
		print date.yellow
		print first.message
		if first.minutes < 60
			time = "#{first.minutes.round(0)} min"
		else
			time = "#{(first.minutes/60.0).round(2)} hrs"
		end
		print " "*($cols-first.message.length-time.length-date.length)
		puts time.light_blue

		sum += first.minutes
	end

	puts " "*($cols-10) + ("-"*10).red
	sum_str = "#{(sum/60.0).round(2)} hrs"
	puts " "*($cols-sum_str.length) + sum_str.red
end

$opts = Trollop::options do
  banner <<-EOS
Clockout v0.1
Usage:
       ./clock.rb [options] <git directory path>

Options:
EOS
  opt :ignore_initial, "Ignore initial commit, if it's just template/boilerplate"
  opt :time, "Minimum time between blocks of commits, in minutes", :default => 120
  opt :include_diffs, "Files to include diffs of when estimating commit time (regex)", :default => "\\.(m|h|txt)$", :type => :string
  opt :ignore_diffs, "Files to ignore diffs of when estimating commit time (regex)", :type => :string
  opt :estimations, "Show estimations made for first commit of each block"
end

path = ARGV.last
Trollop::die "Git repo path must be specified" unless path && File.directory?(path)

repo = Grit::Repo.new(ARGV.last)
commits = repo.commits('master', 500)
commits.reverse!

blocks = seperate_into_blocks(repo, commits)

if ($opts[:estimations])
	print_estimations(blocks)
	puts
end

print_chart(blocks)
