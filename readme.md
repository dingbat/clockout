## :clock9: Clockout ##

You're being paid by the hour, but do you really want to worry about logging your hours? If you're using Git, isn't that already being done for you? Clockout is a tool that analyzes a Git repo and converts your commits into blocks of time worked.

Clockout determines how long each commit took by taking the time interval since the previous one, if it's close enough. With everything added up, Clockout can print out pretty (as far as CLI graphics go) charts and tables to show your boss, and your Git history is the evidence to back it up.

**Install:**
```
$ [sudo] gem install clockout
```

**Display hours worked:**
```
$ cd path/to/git/repo
$ clock
```

![clockout](http://danhassin.com/img/clockout2.png)

**Options:**
```
    --estimations, -e:  Show estimations made, if any
      --condensed, -c:  Condense output (don't show the timeline for each day)
 --user, -u (<email>):  Only count current user's commits (or a given user, if specified)
           --help, -h:  Show this message
```

## :clock5: But, but... ##

What about the first commit in a time block? Say I wake up, work an hour on a feature, and commit it. If there was no previous commit that day to use as a reference point, how will that time be logged?

### Estimation ###

Clockout will estimate a time for a pioneer commit based on the size of its diff, using the diffs-per-hour rate on your other commits.

But sometimes these estimations can be misleading. (Say you've added third-party libraries to your code, which Git says is a lot of additions.) Just add a configuration file to the root of your repo to customize a range of options and make your hours estimations more accurate. Run the following from your repo to generate a template config file:
```
$ clock generate config
```

### Clock-in, clock-out ###

Or, if you're dedicated, Clockout can be a lot more powerful. Right before working, simply run,
```
$ clock in
```
from your repo's directory. The current time will be logged in `clock.yml`, and the time for your next commit will be calculated from the clock-in time to the time that you `git commit`. Nothing more.

Let's say you've committed a feature and you're now spending time doing QA, writing emails, or any work outside of Git. How can you log those additional hours? Welp,
```
$ clock out
```

They work nicely together too, if you're doing work without committing anything.

### Post-commit hook! ###

This is just for fun. Running
```
$ clock generate hook
```
will generate a post-commit hook in your Git repo to call `clock` and print out the length of that commit!

So now you'll see something like this on commit:
```
~/projects/github/clockout $ git commit -m"Update help banner & readme for hook"
[clockout] 16.27 minutes logged
[master eee3499] Update help banner & readme for hook
 4 files changed, 50 insertions(+), 27 deletions(-)
 rewrite clockout-0.5.gem (71%)
```

