require 'rubygems'
require 'grit'
require 'colorize'

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
			c_mins = "#{commit.minutes.round(2)} | "
			char_count += c_mins.length
			print c_mins
		end

		if block_sum > 60
			block_sum_str = "#{(block_sum/60).round(2)}  hr"
		else
			block_sum_str = "#{block_sum.round(2)} min"
		end
		char_count += block_sum_str.length
		puts " "*(100-char_count) + block_sum_str.light_blue

		total_mins += block_sum
	end

	puts " "*(100-10) + ("-"*10).red
	total_str = "= #{(total_mins/60).round(2)} hrs"
	puts " "*(100-total_str.length)+total_str.red
end

repo = Grit::Repo.new(ARGV[0])
commits = repo.commits('master', 500)
commits.reverse!

blocks = seperate_into_blocks(repo, commits)

print_timeline(blocks)
