You're being paid by the hour, but do you really want to worry about logging your hours? If you're using Git, isn't that already being done for you?

Clockout is a tool that'll analyze a Git repository and break down your commits into blocks of time worked, reporting them as hours per day.

How?
======

Clockout determines how long each commit took by taking the time interval since the previous one, if it's close enough. If it's the first commit in a time block, it'll estimate a time for it based on the size of its diff (using the diffs vs. time data from your other commits).

With this data you can print out pretty charts and tables (pretty as CLI graphics go) to show your boss, and your repository is the evidence to back it up.

Usage
======

```./clockout.rb [options] <path to git repo>```

Options:

```
     --ignore-initial, -i:   Ignore initial commit, if it's just template/boilerplate
           --time, -t <i>:   Minimum time between blocks of commits, in minutes (default: 120)
  --include-diffs, -n <s>:   Files to include diffs of when estimating commit time (regex) (default: \.(m|h|txt)$)
   --ignore-diffs, -g <s>:   Files to ignore diffs of when estimating commit time (regex)
        --estimations, -e:   Show estimations made for first commit of each block
               --help, -h:   Show this message
```

Dependencies
======

Grit and Trollop. To install,
```sudo gem install grit trollop```