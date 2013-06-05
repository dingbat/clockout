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
		blocks[1].minutes.should eq(minutes1+minutesPlus)
	end

	it "should work with in-out" do
		c1 = Clock.new(:in, Time.now, nil)
		c2 = Clock.new(:out, c1.date + minutes*60, nil)

		blocks = @clockout.run([c1, c2])[0]

		blocks.size.should eq(1)
		blocks[0].minutes.should eq(minutes)		
	end
end