## :clock9: Clockout ##

You're being paid by the hour, but do you really want to worry about logging your hours? If you're using Git, isn't that already being done for you? Clockout is a tool that analyzes a Git repo and converts your commits into blocks of time worked.

Clockout determines how long each commit took by taking the time interval since the previous one, if it's close enough. With everything added up, Clockout can print out pretty charts and tables (pretty as CLI graphics go) to show your boss, and your Git history is the evidence to back it up.

To install:
```
$ [sudo] gem install clockout
```

To display hours worked:
```
$ cd path/to/git/repo
$ clock [options if you want]
```

Options:
```
    --estimations, -e:  Show estimations made, if any
      --condensed, -c:  Condense output (don't show the timeline for each day)
--generate-config, -g:  Generate config file (clock.yaml)
 --user, -u (<email>):  Only count current user's commits (or specified user)
           --help, -h:  Show this message
```

## :clock5: But, but... ##

What about the first commit in a time block? Say I wake up, work an hour on a feature, and commit it. If there was no previous commit that day to use as a reference point, how will that time be logged?

### Estimation ###

Clockout will estimate a time for a pioneer commit based on the size of its diff, using your diffs-per-hour rate on your other commits.

But sometimes these estimations can be misleading. (Say you've added a third-party library to your code, which Git says is a lot of additions.) Add a configuration file named `clock.yaml` to the root of your repo to customize a range of options to make your hours estimations more accurate. Run `clock -g` to generate a template file.

### Clock-in, clock-out ###

Or, if you're dedicated, Clockout can be a lot more powerful. Right before working, simply run
```
$ clock in
```
at the command line. The current time will be logged in `clock.yaml`, and the time for your next commit will be calculated from the clock-in time to the time that you `git commit`. Nothing more.

Let's say you've committed a feature and you're now spending time doing QA, writing emails, or any work outside of Git. How can you log those additional hours? Welp,
```
$ clock out
```