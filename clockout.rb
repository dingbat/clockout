require 'rubygems'
require 'grit'

repo = Grit::Repo.new(ARGV[0])
commits = repo.commits('master', 500)
commits.reverse!

def seperate_into_blocks(repo, commits)
	blocks = []
	block = []

	commits.each do |commit|
		date = commit.committed_date

		if block.size > 0
			time_since_last = (block.last.committed_date - date).abs/60
			#if it's been 2 hrs since last commit, new block
			if (time_since_last > 120)
				blocks << block
				block = []
			end
		end

		block << commit
	end

	blocks << block
end

blocks = seperate_into_blocks(repo, commits)
blocks.each do |block|
	block.each do |commit|
		puts commit.message
	end
	puts
end