require "spec_helper"

describe Clockout do
	minutes = 10

	before do
    	@clockout = Clockout.new
  	end

	it "should work with commit-commit" do
		c1 = Commit.new
		c1.date = Time.new

		c2 = Commit.new
		c2.date = c1.date + minutes*60

		blocks = @clockout.run([c1, c2])[0]

		blocks.size.should eq(2)
		blocks[0].minutes.should eq(0)
		blocks[1].minutes.should eq(minutes)
	end

	it "should work with in-commit" do
		c1 = Clock.new(:in, Time.new, nil)
		c2 = Commit.new
		c2.date = c1.date + minutes*60

		blocks = @clockout.run([c1, c2])[0]

		blocks.size.should eq(1)
		blocks[0].minutes.should eq(minutes)
	end

	it "should work with commit-in-commit" do
		g1 = 10
		g2 = 20

		c1 = Commit.new(nil, Time.now)
		c2 = Clock.new(:in, c1.date+g1*60, nil)
		c3 = Commit.new(nil, c2.date + g2*60)

		blocks = @clockout.run([c1, c2, c3])[0]

		blocks.size.should eq(2)
		blocks[0].minutes.should eq(0)
		blocks[1].minutes.should eq(g2)
	end

	it "should work with commit-commit-out" do
		minutes1 = 10
		minutesPlus = 15

		c1 = Commit.new
		c1.date = Time.now

		c2 = Commit.new
		c2.date = c1.date + minutes1*60

		c3 = Clock.new(:out, c2.date + minutesPlus*60, nil)

		blocks = @clockout.run([c1, c2, c3])[0]

		blocks.size.should eq(2)
		blocks[0].minutes.should eq(0)
		blocks[1].minutes.should eq(minutes1+minutesPlus)
	end

	it "should work with commit-out-commit" do
		g1 = 10
		g2 = 20

		c1 = Commit.new(nil, Time.now)
		c2 = Clock.new(:out, c1.date + g1*60, nil)
		c3 = Commit.new(nil, c2.date + g2*60)

		blocks = @clockout.run([c1, c2, c3])[0]

		blocks.size.should eq(2)
		blocks[0].minutes.should eq(0)
		blocks[1].minutes.should eq(g2)
	end

	it "should work with in-out" do
		c1 = Clock.new(:in, Time.now, nil)
		c2 = Clock.new(:out, c1.date + minutes*60, nil)

		blocks = @clockout.run([c1, c2])[0]

		blocks.size.should eq(1)
		blocks[0].minutes.should eq(minutes)		
	end

	it "should work with multiple ins" do
		g1 = 10
		g2 = 20

		c1 = Clock.new(:in, Time.now, nil)
		c2 = Clock.new(:in, c1.date + g1*60, nil)
		c3= Commit.new(nil, c2.date + g2*60)

		blocks = @clockout.run([c1, c2, c3])[0]

		blocks.size.should eq(1)
		blocks[0].minutes.should eq(g2)
	end

	it "should work with multiple outs" do
		g1 = 10
		g2 = 20
		g3 = 30

		c1= Commit.new(nil, Time.now)
		c2= Commit.new(nil, c1.date + g1*60)
		c3 = Clock.new(:out, c2.date + g2*60, nil)
		c4 = Clock.new(:out, c3.date + g3*60, nil)

		blocks = @clockout.run([c1, c2, c3, c4])[0]

		blocks.size.should eq(2)
		blocks[1].minutes.should eq(g1+g2+g3)
	end

	# it "should work on this random sequence" do
	# 	mins = [10, 15, 20, 25, 30]

	# 	c1 = Clock.new(:in, Time.now, nil)
	# 	c2 = Commit.new(c1.time + mins[0]*60)
	# 	c3 = Commit.new(c2.time + mins[1]*60)
	# 	c3 = Clock.new(:out, c3 + mins[1]*60)
	# end
end