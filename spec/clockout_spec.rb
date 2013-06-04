require "spec_helper"

describe Clockout do
	before do
    	@clockout = Clockout.new
  	end

	it "should work with commit-commit" do
		c1 = Commit.new
		c1.date = Time.new

		minutes = 10

		c2 = Commit.new
		c2.date = c1.date + minutes*60

		blocks = @clockout.run([c1, c2])[0]
		p blocks

		blocks.size.should eq(2)
		blocks[1].minutes.should eq(minutes)
	end

	it "should work with in-commit" do

	end

	it "should work with commit-out" do
	end

	it "should work with in-out" do
	end
end