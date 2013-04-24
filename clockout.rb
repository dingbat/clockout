require 'rubygems'
require 'grit'
require 'colorize'

$cols = 100

class Commit
	attr_accessor :message, :minutes, :date
end

def estimate_commit_minutes(commit)
	plus, minus = 0, 0

	commit.stats.to_diffstat.each do |diff_stat|
		# make sure the change was with code (adding, say, an image will give tons of additions)
		code = (diff_stat.filename =~ /\.(m|h|txt)$/)
		# I didn't write this file, ignore it
		lx = (diff_stat.filename =~ /LXReorderableCollectionViewFlowLayout/)
		if code && !lx
			plus += diff_stat.additions
			minus += diff_stat.deletions
		end
	end

	#estimating (through trial and error) 4 additions and 8 deletions per minute
	return (plus/4+minus/8)
end

def seperate_into_blocks(repo, commits)
	blocks = []
	block = []

	commits.each do |commit|

		c = Commit.new
		c.date = commit.committed_date
		c.message = commit.message

		if block.size > 0
			time_since_last = (block.last.date - commit.committed_date).abs/60
			
			if (time_since_last > 120) #new block cutoff at 2 hrs
				blocks << block
				block = []
			else
				c.minutes = time_since_last
			end
		end


		#first commit of the new block, so we don't know when work started. estimate
		if !c.minutes
			c.minutes = estimate_commit_minutes(commit)
		end

		block << c
	end

	blocks << block
end

def print_timeline(blocks)
	total_mins = 0
	blocks.each do |block|
		block_sum = 0
		char_count = 0

		date = block.first.date.strftime('%b %e, %l:%M %p')+":  "
		char_count += date.length
		print date.yellow

		block.each do |commit|
			block_sum += commit.minutes
			if commit.minutes < 60
				c_mins = "#{commit.minutes.round(0)}m | "
			else
				c_mins = "#{(commit.minutes/60.0).round(1)}h | "
			end
			char_count += c_mins.length
			print c_mins
		end

		if block_sum > 60
			block_sum_str = "#{(block_sum/60.0).round(2)} hrs"
		else
			block_sum_str = "#{block_sum.round(0)} min"
		end
		char_count += block_sum_str.length
		puts " "*($cols-char_count) + block_sum_str.light_blue

		total_mins += block_sum
	end

	puts " "*($cols-10) + ("-"*10).red
	total_str = "= #{(total_mins/60.0).round(2)} hrs"
	puts " "*($cols-total_str.length)+total_str.red
end

def print_estimations(blocks)
	sum = 0
	blocks.each do |block|
		first = block.first
		print first.message[0..70]
		if first.minutes < 60
			time = "#{first.minutes.round(0)} min"
		else
			time = "#{(first.minutes/60.0).round(2)} hr"
		end
		print " "*($cols-first.message[0..70].length-time.length)
		puts time.light_blue

		sum += first.minutes
	end

	puts " "*($cols-10) + ("-"*10).red
	sum_str = "#{(sum/60.0).round(2)} hr"
	puts " "*($cols-sum_str.length) + sum_str.red
end

def print_days(blocks)
	current_mins = 0
	current_day = nil

	print_current_data = lambda do
		hrs = "#{(current_mins/60.0).round(2)} hrs"

		print current_day
		print " "*($cols/4 - current_day.length - hrs.length)
		puts hrs.light_blue
	end

	blocks.each do |block|
		block.each do |commit|
			day = commit.date.strftime('%b %e')
			if (day != current_day)
				if (current_day)
					print_current_data.call
				end
				current_day = day
				current_mins = 0
			end
			current_mins += commit.minutes
		end
	end

	print_current_data.call
end

repo = Grit::Repo.new(ARGV[0])
commits = repo.commits('master', 500)
commits.reverse!

blocks = seperate_into_blocks(repo, commits)

print_estimations(blocks)
puts
print_timeline(blocks)
puts
print_days(blocks)
