require "spec_helper"

describe Clockout do
	before do
    	@clockout = Clockout.new
  	end

  	def run_commits(commits, minutes)
  		minutes = [minutes] if minutes == minutes.flatten

  		blocks = @clockout.run(commits)
  		minutes.each_with_index do |mins, b_idx|
			block = blocks[b_idx]

			block.size.should eq(mins.size)
			mins.each_with_index do |min, idx|
				block[idx].minutes.should eq(min)
			end
  		end
  	end

  	# TIMES
	minutes = 10

	it "should work with commit-commit" do
		c1 = Commit.new(nil, Time.new)
		c2 = Commit.new(nil, c1.date + minutes*60)

		run_commits([c1, c2], [0, minutes])
	end

	it "should work with in-commit" do
		c1 = Clock.new(:in, Time.new, nil)
		c2 = Commit.new(nil, c1.date + minutes*60)

		run_commits([c1, c2], [minutes])
	end

	it "should work with commit-in-commit" do
		g1 = 10
		g2 = 20

		c1 = Commit.new(nil, Time.now)
		c2 = Clock.new(:in, c1.date+g1*60, nil)
		c3 = Commit.new(nil, c2.date + g2*60)

		run_commits([c1, c2, c3], [0, g2])
	end

	it "should work with commit-commit-out" do
		minutes1 = 10
		minutesPlus = 15

		c1 = Commit.new(nil, Time.now)
		c2 = Commit.new(nil, c1.date + minutes1*60)
		c3 = Clock.new(:out, c2.date + minutesPlus*60, nil)

		run_commits([c1, c2, c3], [0, minutes1+minutesPlus])
	end

	it "should work with commit-out-commit" do
		g1 = 10
		g2 = 20

		c1 = Commit.new(nil, Time.now)
		c2 = Clock.new(:out, c1.date + g1*60, nil)
		c3 = Commit.new(nil, c2.date + g2*60)

		run_commits([c1, c2, c3], [10, g2])
	end

	it "should work with in-out" do
		c1 = Clock.new(:in, Time.now, nil)
		c2 = Clock.new(:out, c1.date + minutes*60, nil)

		run_commits([c1, c2], [minutes])
	end

	it "should work with multiple ins" do
		g1 = 10
		g2 = 20

		c1 = Clock.new(:in, Time.now, nil)
		c2 = Clock.new(:in, c1.date + g1*60, nil)
		c3= Commit.new(nil, c2.date + g2*60)

		run_commits([c1, c2, c3], [g2])
	end

	it "should work with multiple outs" do
		g1 = 10
		g2 = 20
		g3 = 30

		c1= Commit.new(nil, Time.now)
		c2= Commit.new(nil, c1.date + g1*60)
		c3 = Clock.new(:out, c2.date + g2*60, nil)
		c4 = Clock.new(:out, c3.date + g3*60, nil)

		run_commits([c1, c2, c3, c4], [0, g1+g2+g3])
	end

	it "should work on this random sequence" do
		c_in = Clock.new(:in, Time.now, nil)
		c10 = Commit.new(nil, c_in.date + 10*60)
		c30 = Commit.new(nil, c10.date + 18*60)
		c_out = Clock.new(:out, c10.date + 30*60, nil)
		c_20 = Commit.new(nil, c_out.date + 20*60)

		run_commits([c_in, c10, c30, c_out, c_20], [10, 30, 20])
	end

	# SPLITUPS
	it "should work with commit-commit" do
		c1 = Commit.new(nil, Time.new)
		c2 = Commit.new(nil, c1.date + 250*60)

		run_commits([c1, c2], [[0], [0]])
	end

	it "should work with in-commit" do
		mins = 250

		c1 = Clock.new(:in, Time.new, nil)
		c2 = Commit.new(nil, c1.date + mins*60)

		run_commits([c1, c2], [mins])
	end

	it "should work with commit-in-commit" do
		g1 = 250
		g2 = 40

		c1 = Commit.new(nil, Time.now)
		c2 = Clock.new(:in, c1.date+g1*60, nil)
		c3 = Commit.new(nil, c2.date + g2*60)

		run_commits([c1, c2, c3], [[0], [g2]])
	end

	it "should work with commit-commit-out" do
		minutes1 = 20
		minutesPlus = 300

		c1 = Commit.new(nil, Time.now)
		c2 = Commit.new(nil, c1.date + minutes1*60)
		c3 = Clock.new(:out, c2.date + minutesPlus*60, nil)

		run_commits([c1, c2, c3], [0, minutesPlus+minutes1])
	end

	it "should work with in-out" do
		mins = 250

		c1 = Clock.new(:in, Time.now, nil)
		c2 = Clock.new(:out, c1.date + mins*60, nil)
		c3 = Clock.new(:in, c2.date + 20*60, nil)
		c4 = Clock.new(:out, c3.date + mins*60, nil)
		c5 = Clock.new(:in, c4.date + 300*60, nil)
		c6 = Clock.new(:out, c5.date + mins*60, nil)

		run_commits([c1, c2, c3, c4, c5, c6], [[mins, mins], [mins]])
	end
end