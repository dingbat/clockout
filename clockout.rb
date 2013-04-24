require 'rubygems'
require 'grit'

repo = Grit::Repo.new(ARGV[0])
commits = repo.commits('master', 500)
commits.reverse!

class Commit
	attr_accessor :message, :minutes, :date
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