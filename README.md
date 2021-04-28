# Shell::Config::Generate ![linux](https://github.com/plicease/Shell-Config-Generate/workflows/linux/badge.svg) ![macos](https://github.com/plicease/Shell-Config-Generate/workflows/macos/badge.svg) ![windows](https://github.com/plicease/Shell-Config-Generate/workflows/windows/badge.svg) ![cygwin](https://github.com/plicease/Shell-Config-Generate/workflows/cygwin/badge.svg) ![msys2-mingw](https://github.com/plicease/Shell-Config-Generate/workflows/msys2-mingw/badge.svg)

Portably generate config for any shell

# SYNOPSIS

With this start up:

```perl
use Shell::Guess;
use Shell::Config::Generate;

my $config = Shell::Config::Generate->new;
$config->comment( 'this is my config file' );
$config->set( FOO => 'bar' );
$config->set_path(
  PERL5LIB => '/foo/bar/lib/perl5',
              '/foo/bar/lib/perl5/perl5/site',
);
$config->append_path(
  PATH => '/foo/bar/bin',
          '/bar/foo/bin',
);
```

This:

```
$config->generate_file(Shell::Guess->bourne_shell, 'config.sh');
```

will generate a config.sh file with this:

```perl
# this is my config file
FOO='bar';
export FOO;
PERL5LIB='/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site';
export PERL5LIB;
if [ -n "$PATH" ] ; then
  PATH=$PATH:'/foo/bar/bin:/bar/foo/bin';
  export PATH
else
  PATH='/foo/bar/bin:/bar/foo/bin';
  export PATH;
fi;
```

and this:

```
$config->generate_file(Shell::Guess->c_shell, 'config.csh');
```

will generate a config.csh with this:

```perl
# this is my config file
setenv FOO 'bar';
setenv PERL5LIB '/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site';
test "$?PATH" = 0 && setenv PATH '/foo/bar/bin:/bar/foo/bin' || setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin';
```

and this:

```
$config->generate_file(Shell::Guess->cmd_shell, 'config.cmd');
```

will generate a `config.cmd` (Windows `cmd.exe` script) with this:

```perl
rem this is my config file
set FOO=bar
set PERL5LIB=/foo/bar/lib/perl5;/foo/bar/lib/perl5/perl5/site
if defined PATH (set PATH=%PATH%;/foo/bar/bin;/bar/foo/bin) else (set PATH=/foo/bar/bin;/bar/foo/bin)
```

# DESCRIPTION

This module provides an interface for specifying shell configurations
for different shell environments without having to worry about the
arcane differences between shells such as csh, sh, cmd.exe and command.com.

It does not modify the current environment, but it can be used to
create shell configurations which do modify the environment.

This module uses [Shell::Guess](https://metacpan.org/pod/Shell::Guess) to represent the different types
of shells that are supported.  In this way you can statically specify
just one or more shells:

```perl
#!/usr/bin/perl
use Shell::Guess;
use Shell::Config::Generate;
my $config = Shell::Config::Generate->new;
# ... config config ...
$config->generate_file(Shell::Guess->bourne_shell,  'foo.sh' );
$config->generate_file(Shell::Guess->c_shell,       'foo.csh');
$config->generate_file(Shell::Guess->cmd_shell,     'foo.cmd');
$config->generate_file(Shell::Guess->command_shell, 'foo.bat');
```

This will create foo.sh and foo.csh versions of the configurations,
which can be sourced like so:

```
#!/bin/sh
. ./foo.sh
```

or

```
#!/bin/csh
source foo.csh
```

It also creates `.cmd` and `.bat` files with the same configuration
which can be used in Windows.  The configuration can be imported back
into your shell by simply executing these files:

```
C:\> foo.cmd
```

or

```
C:\> foo.bat
```

Alternatively you can use the shell that called your Perl script using
[Shell::Guess](https://metacpan.org/pod/Shell::Guess)'s `running_shell` method, and write the output to
standard out.

```perl
#!/usr/bin/perl
use Shell::Guess;
use Shell::Config::Generate;
my $config = Shell::Config::Generate->new;
# ... config config ...
print $config->generate(Shell::Guess->running_shell);
```

If you use this pattern, you can eval the output of your script using
your shell's back ticks to import the configuration into the shell.

```
#!/bin/sh
eval `script.pl`
```

or

```
#!/bin/csh
eval `script.pl`
```

# CONSTRUCTOR

## new

```perl
my $config = Shell::Config::Generate->new;
```

creates an instance of She::Config::Generate.

# METHODS

There are two types of instance methods for this class:

- modifiers

    adjust the configuration in an internal portable format

- generators

    generate shell configuration in a specific format given
    the internal portable format stored inside the instance.

The idea is that you can create multiple modifications
to the environment without worrying about specific shells,
then when you are done you can create shell specific
versions of those modifications using the generators.

This may be useful for system administrators that must support
users that use different shells, with a single configuration
generation script written in Perl.

## set

```perl
$config->set( $name => $value );
```

Set an environment variable.

## set\_path

```perl
$config->set_path( $name => @values );
```

Sets an environment variable which is stored in standard
'path' format (Like PATH or PERL5LIB).  In UNIX land this
is a colon separated list stored as a string.  In Windows
this is a semicolon separated list stored as a string.
You can do the same thing using the `set` method, but if
you do so you have to determine the correct separator.

This will replace the existing path value if it already
exists.

## append\_path

```perl
$config->append_path( $name => @values );
```

Appends to an environment variable which is stored in standard
'path' format.  This will create a new environment variable if
it doesn't already exist, or add to an existing value.

## prepend\_path

```perl
$config->prepend_path( $name => @values );
```

Prepend to an environment variable which is stored in standard
'path' format.  This will create a new environment variable if
it doesn't already exist, or add to an existing value.

## comment

```
$config->comment( $comment );
```

This will generate a comment in the appropriate format.

**note** that including comments in your configuration may mean
it will not work with the `eval` backticks method for importing
configurations into your shell.

## shebang

```
$config->shebang;
$config->shebang($location);
```

This will generate a shebang at the beginning of the configuration,
making it appropriate for use as a script.  For non UNIX shells this
will be ignored.  If specified, `$location` will be used as the
interpreter location.  If it is not specified, then the default
location for the shell will be used.

**note** that the shebang in your configuration may mean
it will not work with the `eval` backticks method for importing
configurations into your shell.

## echo\_off

```
$config->echo_off;
```

For DOS/Windows configurations (`command.com` or `cmd.exe`), issue this as the
first line of the config:

```
@echo off
```

## echo\_on

```
$config->echo_on;
```

Turn off the echo off (that is do not put anything at the beginning of
the config) for DOS/Windows configurations (`command.com` or `cmd.exe`).

## set\_alias

```perl
$config->set_alias( $alias => $command )
```

Sets the given alias to the given command.

Caveat:
some older shells do not support aliases, such as
the original bourne shell.  This module will generate
aliases for those shells anyway, since /bin/sh may
actually be a more modern shell that DOES support
aliases, so do not use this method unless you can be
reasonable sure that the shell you are generating
supports aliases.  On Windows, for PowerShell, a simple
function is used instead of an alias so that arguments
may be specified.

## set\_path\_sep

```
$config->set_path_sep( $sep );
```

Use `$sep` as the path separator instead of the shell
default path separator (generally `:` for Unix shells
and `;` for Windows shells).

Not all characters are supported, it is usually best
to stick with the shell default or to use `:` or `;`.

## generate

```perl
my $command_text = $config->generate;
my $command_text = $config->generate( $shell );
```

Generate shell configuration code for the given shell.
`$shell` is an instance of [Shell::Guess](https://metacpan.org/pod/Shell::Guess).  If `$shell`
is not provided, then this method will use Shell::Guess
to guess the shell that called your perl script.

You can also pass in the shell name as a string for
`$shell`.  This should correspond to the appropriate
_name_\_shell from [Shell::Guess](https://metacpan.org/pod/Shell::Guess).  So for csh you
would pass in `"c"` and for tcsh you would pass in
`"tc"`, etc.

## generate\_file

```
$config->generate_file( $shell, $filename );
```

Generate shell configuration code for the given shell
and write it to the given file.  `$shell` is an instance
of [Shell::Guess](https://metacpan.org/pod/Shell::Guess).  If there is an IO error it will throw
an exception.

# FUNCTIONS

## win32\_space\_be\_gone

```perl
my @new_path_list = win32_space_be_gone( @orig_path_list );
```

On `MSWin32` and `cygwin`:

Given a list of directory paths (or filenames), this will
return an equivalent list of paths pointing to the same
file system objects without spaces.  To do this
`Win32::GetShortPathName()` is used on to find alternative
path names without spaces.

NOTE that this breaks when Windows is told not to create
short (`8+3`) filenames; see [http://www.perlmonks.org/?node\_id=333930](http://www.perlmonks.org/?node_id=333930)
for a discussion of this behaviour.

In addition, on just `Cygwin`:

The input paths are first converted from POSIX to Windows paths
using `Cygwin::posix_to_win_path`, and then converted back to
POSIX paths using `Cygwin::win_to_posix_path`.

Elsewhere:

Returns the same list passed into it

## cmd\_escape\_path

```perl
my @new_path_list = cmd_escape_path( @orig_path_list )
```

Given a list of directory paths (or filenames), this will
return an equivalent list of paths escaped for cmd.exe and command.com.

## powershell\_escape\_path

```perl
my @new_path_list = powershell_escape_path( @orig_path_list )
```

Given a list of directory paths (or filenames), this will
return an equivalent list of paths escaped for PowerShell.

# CAVEATS

The test suite tests this module's output against the actual
shells that should understand them, if they can be found in
the path.  You can generate configurations for shells which
are not available (for example `cmd.exe` configurations from UNIX or
bourne configurations under windows), but the test suite only tests
them if they are found during the build of this module.

The implementation for `csh` depends on the external command `test`.
As far as I can tell `test` should be available on all modern
flavors of UNIX which are using `csh`.  If anyone can figure out
how to prepend or append to path type environment variable without
an external command in `csh`, then a patch would be appreciated.

The incantation for prepending and appending elements to a path
on csh probably deserve a comment here.  It looks like this:

```
test "$?PATH" = 0 && setenv PATH '/foo/bar/bin:/bar/foo/bin' || setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin';
```

- one line

    The command is all on one line, and doesn't use if, which is
    probably more clear and ideomatic.  This for example, might
    make more sense:

    ```
    if ( $?PATH == 0 ) then
      setenv PATH '/foo/bar/bin:/bar/foo/bin'
    else
      setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin'
    endif
    ```

    However, this only works if the code interpreted using the csh
    `source` command or is included in a csh script inline.  If you
    try to invoke this code using csh `eval` then it will helpfully
    convert it to one line and if does not work under csh in one line.

There are probably more clever or prettier ways to
append/prepend path environment variables as I am not a shell
programmer.  Patches welcome.

Only UNIX (bourne, bash, csh, ksh, fish and their derivatives) and
Windows (command.com, cmd.exe and PowerShell) are supported so far.

Fish shell support should be considered a tech preview.  The Fish
shell itself is somewhat in flux, and thus some tests are skipped
for the Fish shell since behavior is different for different versions.
In particular, new lines in environment variables may not work on
newer versions.

Patches welcome for your favorite shell / operating system.

# AUTHOR

Author: Graham Ollis <plicease@cpan.org>

Contributors:

Brad Macpherson (BRAD, brad-mac)

mohawk

# COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
