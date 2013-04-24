require 'rubygems'
require 'grit'

repo = Grit::Repo.new(ARGV[0])
commits = repo.commits('master', 500)
commits.reverse!

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
		c.minutes = 0

		if block.size > 0
			time_since_last = (block.last.date - commit.committed_date).abs/60
			
			if (time_since_last > 120) #new block cutoff at 2 hrs
				blocks << block
				block = []

				#first commit of the block, so we don't know when work started
				c.minutes = estimate_commit_minutes(commit)
			else
				c.minutes = time_since_last
			end
		end

		block << c
	end

	blocks << block
end

blocks = seperate_into_blocks(repo, commits)
blocks.each do |block|
	block.each do |commit|
		puts "#{commit.minutes.round(2)} #{commit.message}"
	end
	puts
end