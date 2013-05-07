# :clock8: Clockout#

You're being paid by the hour, but do you really want to worry about logging your hours? If you're using Git, isn't that already being done for you? **Clockout** is a tool that analyzes a Git repo and converts your commits into blocks of time worked.

How?
--------

Clockout determines how long each commit took by taking the time interval since the previous one, if it's close enough. If it's the first commit in a time block, it'll estimate a time for it based on the size of its diff (using the diffs vs. time data from your other commits).

With this data you can print out pretty charts and tables (pretty as CLI graphics go) to show your boss, and your repository is the evidence to back it up.

Usage
--------

To install:

```
$ gem install clockout
```

To display hours worked:

```
$ cd path/to/git/repo
$ clock [options]
```

Options:

```
    --estimations, -e:   Show estimations made for first commit of each block
      --condensed, -c:   Condense output (don't show the timeline for each day)
 --generate-clock, -g:   Generate .clock file
      --see-clock, -s:   See options specified in .clock file
           --help, -h:   Show this message
```