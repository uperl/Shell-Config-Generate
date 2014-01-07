# Shell::Config::Generate [![Build Status](https://secure.travis-ci.org/plicease/Shell-Config-Generate.png)](http://travis-ci.org/plicease/Shell-Config-Generate)

Portably generate config for any shell

# SYNOPSIS

With this start up:

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

This:

    $config->generate_file(Shell::Guess->bourne_shell, 'config.sh');

will generate a config.sh file with this:

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

and this:

    $config->generate_file(Shell::Guess->c_shell, 'config.csh');

will generate a config.csh with this:

    # this is my config file
    setenv FOO 'bar';
    setenv PERL5LIB '/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site';
    test "$?PATH" = 0 && setenv PATH '/foo/bar/bin:/bar/foo/bin' || setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin';

and this:

    $config->generate_file(Shell::Guess->cmd_shell, 'config.cmd');

will generate a `config.cmd` (Windows `cmd.exe` script) with this:

    rem this is my config file
    set FOO=bar
    set PERL5LIB=/foo/bar/lib/perl5;/foo/bar/lib/perl5/perl5/site
    if defined PATH (set PATH=%PATH%;/foo/bar/bin;/bar/foo/bin) else (set PATH=/foo/bar/bin;/bar/foo/bin)

# DESCRIPTION

This module provides an interface for specifying shell configurations
for different shell environments without having to worry about the 
arcane differences between shells such as csh, sh, cmd.exe and command.com.

It does not modify the current environment, but it can be used to
create shell configurations which do modify the environment.

This module uses [Shell::Guess](https://metacpan.org/pod/Shell::Guess) to represent the different types
of shells that are supported.  In this way you can statically specify
just one or more shells:

    #!/usr/bin/perl
    use Shell::Guess;
    use Shell::Config::Generate;
    my $config = Shell::Config::Generate->new;
    # ... config config ...
    $config->generate_file(Shell::Guess->bourne_shell,  'foo.sh' );
    $config->generate_file(Shell::Guess->c_shell,       'foo.csh');
    $config->generate_file(Shell::Guess->cmd_shell,     'foo.cmd');
    $config->generate_file(Shell::Guess->command_shell, 'foo.bat');

This will create foo.sh and foo.csh versions of the configurations,
which can be sourced like so:

    #!/bin/sh
    . ./foo.sh

or

    #!/bin/csh
    source foo.csh

It also creates `.cmd` and `.bat` files with the same configuration
which can be used in Windows.  The configuration can be imported back
into your shell by simply executing these files:

    C:\> foo.cmd

or

    C:\> foo.bat

Alternatively you can use the shell that called your Perl script using
[Shell::Guess](https://metacpan.org/pod/Shell::Guess)'s `running_shell` method, and write the output to
standard out.

    #!/usr/bin/perl
    use Shell::Guess;
    use Shell::Config::Generate;
    my $config = Shell::Config::Generate->new;
    # ... config config ...
    print $config->generate(Shell::Guess->running_shell);

If you use this pattern, you can eval the output of your script using
your shell's back ticks to import the configuration into the shell.

    #!/bin/sh
    eval `script.pl`

or

    #!/bin/csh
    eval `script.pl`

# CONSTRUCTOR

## Shell::Config::Generate->new

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

## $config->set( $name => $value )

Set an environment variable.

## $config->set\_path( $name => @values )

Sets an environment variable which is stored in standard
'path' format (Like PATH or PERL5LIB).  In UNIX land this 
is a colon separated list stored as a string.  In Windows 
this is a semicolon separated list stored as a string.
You can do the same thing using the `set` method, but if
you do so you have to determine the correct separator.

This will replace the existing path value if it already
exists.

## $config->append\_path( $name => @values );

Appends to an environment variable which is stored in standard
'path' format.  This will create a new environment variable if
it doesn't already exist, or add to an existing value.

## $config->prepend\_path( $name => @values );

Prepend to an environment variable which is stored in standard
'path' format.  This will create a new environment variable if
it doesn't already exist, or add to an existing value.

## $config->comment( $comment )

This will generate a comment in the appropriate format.

__note__ that including comments in your configuration may mean
it will not work with the `eval` backticks method for importing
configurations into your shell.

## $config->shebang( \[ $location \] )

This will generate a shebang at the beginning of the configuration,
making it appropriate for use as a script.  For non UNIX shells this
will be ignored.  If specified, $location will be used as the 
interpreter location.  If it is not specified, then the default
location for the shell will be used.

__note__ that the shebang in your configuration may mean
it will not work with the `eval` backticks method for importing
configurations into your shell.

## $config->echo\_off

For DOS/Windows configurations (`command.com` or `cmd.exe`), issue this as the
first line of the config:

    @echo off

## $config->echo\_on

Turn off the echo off (that is do not put anything at the beginning of
the config) for DOS/Windows configurations (`command.com` or `cmd.exe`).

## $config->generate( \[ $shell \] )

Generate shell configuration code for the given shell.
$shell is an instance of [Shell::Guess](https://metacpan.org/pod/Shell::Guess).  If $shell
is not provided, then this method will use Shell::Guess
to guess the shell that called your perl script.

## $config->generate\_file( $shell, $filename )

Generate shell configuration code for the given shell
and write it to the given file.  $shell is an instance 
of [Shell::Guess](https://metacpan.org/pod/Shell::Guess).  If there is an IO error it will throw
an exception.

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

    test "$?PATH" = 0 && setenv PATH '/foo/bar/bin:/bar/foo/bin' || setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin';

- one line

    The command is all on one line, and doesn't use if, which is 
    probably more clear and ideomatic.  This for example, might 
    make more sense:

        if ( $?PATH == 0 ) then
          setenv PATH '/foo/bar/bin:/bar/foo/bin' 
        else
          setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin'
        endif

    However, this only works if the code interpreted using the csh
    `source` command or is included in a csh script inline.  If you 
    try to invoke this code using csh `eval` then it will helpfully
    convert it to one line and if does not work under csh in one line.

There are probably more clever or prettier ways to 
append/prepend path environment variables as I am not a shell
programmer.  Patches welcome.

Only UNIX and Windows are supported so far.  Patches welcome.

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
