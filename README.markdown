## Respec

Provides a command, `respec`, which wraps `rspec`, and records your
failing examples for easy rerunning.

## How?

Run your specs:

    respec

3 fail. Rerun just the 3 failures like this:

    respec f

Need to debug failure #1? Pop a `debugger` in your code, and rerun it
like this:

    respec 1

This will just rerun failure 1. Once it's passing, rerun the 3 failing
examples again:

    respec f

1 is now fixed, but 2 and 3 are still failing - `respec f` will now
only run failures 2 and 3 again.

## How it works

All that's happening is the list of failed examples is being recorded
in a file (`.respec_failures`). The `f` argument means "run these
recorded failures only." A numeric argument like `1` means "just run
that failure."

The list of failed examples is always updated _except_ when selecting
which failures to rerun with a number (more than one number can also
be given, incidentally).

## Other tricks

You can pass `respec` file or directory names, just like
`rspec`. However, you can also just specify example names on the
command line:

    respec 'My example name'

If the argument doesn't name an existing file, it's assumed to be an
example name.

It'll even `bundle exec` for you automatically.

There are a few other shortcuts. `respec --help` to see them all.

## Contributing

 * [Bug reports](https://github.com/oggy/respec/issues)
 * [Source](https://github.com/oggy/respec)
 * Patches: Fork on Github, send pull request.
   * Include tests where practical.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) George Ogata. See LICENSE for details.
