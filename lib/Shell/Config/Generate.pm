package Shell::Config::Generate;

use strict;
use warnings;
use Shell::Guess;

# ABSTRACT: Portably generate config for any shell
# VERSION

=head1 SYNOPSIS

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
 export FOO='bar';
 export PERL5LIB='/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site';
 if [ -n "$PATH" ] ; then
   export PATH=$PATH:'/foo/bar/bin:/bar/foo/bin';
 else
   export PATH='/foo/bar/bin:/bar/foo/bin';
 fi;

and this:

 $config->generate_file(Shell::Guess->c_shell, 'config.csh');

will generate a config.csh with this:

 # this is my config file
 setenv FOO 'bar';
 setenv PERL5LIB '/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site';
 [ $?PATH = 0 ] && setenv PATH '/foo/bar/bin:/bar/foo/bin' || setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin';

and this:

 $config->generate_file(Shell::Guess->cmd_shell, 'config.cmd');

will generate a C<config.cmd> (Windows C<cmd.exe> script) with this:

 rem this is my config file
 set FOO=bar
 set PERL5LIB=/foo/bar/lib/perl5;/foo/bar/lib/perl5/perl5/site
 if defined PATH (set PATH=%PATH%;/foo/bar/bin;/bar/foo/bin) else (set PATH=/foo/bar/bin;/bar/foo/bin)

=head1 DESCRIPTION

This module provides an interface for specifying shell configurations
for different shell environments without having to worry about the 
arcane differences between shells such as csh, sh, cmd.exe and command.com.

It does not modify the current environment, but it can be used to
create shell configurations which do modify the environment.

This module uses L<Shell::Guess> to represent the different types
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

It also creates C<.cmd> and C<.bat> files with the same configuration
which can be used in Windows.  The configuration can be imported back
into your shell by simply executing these files:

 C:\> foo.cmd

or

 C:\> foo.bat

Alternatively you can use the shell that called your Perl script using
L<Shell::Guess>'s C<running_shell> method, and write the output to
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

=head1 CONSTRUCTOR

=head2 Shell::Config::Generate->new

creates an instance of She::Config::Generate.

=cut

sub new
{
  my($class) = @_;
  bless { commands => [], echo_off => 0 }, $class;
}

=head1 METHODS

There are two types of instance methods for this class:

=over 4

=item * modifiers

adjust the configuration in an internal portable format

=item * generators

generate shell configuration in a specific format given
the internal portable format stored inside the instance.

=back

The idea is that you can create multiple modifications
to the environment without worrying about specific shells, 
then when you are done you can create shell specific 
versions of those modifications using the generators.

This may be useful for system administrators that must support
users that use different shells, with a single configuration
generation script written in Perl.

=head2 $config-E<gt>set( $name => $value )

Set an environment variable.

=cut

sub set
{
  my($self, $name, $value) = @_;

  push @{ $self->{commands} }, ['set', $name, $value];

  $self;
}

=head2 $config-E<gt>set_path( $name => @values )

Sets an environment variable which is stored in standard
'path' format (Like PATH or PERL5LIB).  In UNIX land this 
is a colon separated list stored as a string.  In Windows 
this is a semicolon separated list stored as a string.
You can do the same thing using the C<set> method, but if
you do so you have to determine the correct separator.

This will replace the existing path value if it already
exists.

=cut

sub set_path
{
  my($self, $name, @list) = @_;

  push @{ $self->{commands} }, [ 'set_path', $name, @list ];

  $self;
}

=head2 $config-E<gt>append_path( $name => @values );

Appends to an environment variable which is stored in standard
'path' format.  This will create a new environment variable if
it doesn't already exist, or add to an existing value.

=cut

sub append_path
{
  my($self, $name, @list) = @_;

  push @{ $self->{commands} }, [ 'append_path', $name, @list ]
    if @list > 0;

  $self;
}

=head2 $config-E<gt>prepend_path( $name => @values );

Prepend to an environment variable which is stored in standard
'path' format.  This will create a new environment variable if
it doesn't already exist, or add to an existing value.

=cut

sub prepend_path
{
  my($self, $name, @list) = @_;

  push @{ $self->{commands} }, [ 'prepend_path', $name, @list ]
    if @list > 0;

  $self;
}

=head2 $config-E<gt>comment( $comment )

This will generate a comment in the appropriate format.

B<note> that including comments in your configuration may mean
it will not work with the C<eval> backticks method for importing
configurations into your shell.

=cut

sub comment
{
  my($self, @comments) = @_;

  push @{ $self->{commands} }, ['comment', $_] for @comments;

  $self;
}

=head2 $config-E<gt>shebang( [ $location ] )

This will generate a shebang at the beginning of the configuration,
making it appropriate for use as a script.  For non UNIX shells this
will be ignored.  If specified, $location will be used as the 
interpreter location.  If it is not specified, then the default
location for the shell will be used.

B<note> that the shebang in your configuration may mean
it will not work with the C<eval> backticks method for importing
configurations into your shell.

=cut

sub shebang
{
  my($self, $location) = @_;
  $self->{shebang} = $location;
  $self;
}

=head2 $config-E<gt>echo_off

For DOS/Windows configurations (C<command.com> or C<cmd.exe>), issue this as the
first line of the config:

 @echo off

=cut

sub echo_off
{
  my($self) = @_;
  $self->{echo_off} = 1;
  $self;
}

=head2 $config-E<gt>echo_on

Turn off the echo off (that is do not put anything at the beginning of
the config) for DOS/Windows configurations (C<command.com> or C<cmd.exe>).

=cut

sub echo_on
{
  my($self) = @_;
  $self->{echo_off} = 0;
  $self;
}

sub _value_escape_csh
{
  my $value = shift() . '';
  $value =~ s/([\n!])/\\$1/g;
  $value =~ s/(')/'"$1"'/g;
  $value;
}

sub _value_escape_sh
{
  my $value = shift() . '';
  $value =~ s/(')/'"$1"'/g;
  $value;
}

sub _value_escape_win32
{
  my $value = shift() . '';
  $value =~ s/%/%%/g;
  $value =~ s/([&^|<>])/^$1/g;
  $value =~ s/\n/^\n\n/g;
  $value;
}

=head2 $config-E<gt>generate( [ $shell ] )

Generate shell configuration code for the given shell.
$shell is an instance of L<Shell::Guess>.  If $shell
is not provided, then this method will use Shell::Guess
to guess the shell that called your perl script.

=cut

sub generate
{
  my($self, $shell) = @_;

  $shell ||= Shell::Guess->running_shell;
  
  my $buffer = '';

  if(exists $self->{shebang} && $shell->is_unix)
  {
    if(defined $self->{shebang})
    { $buffer .= "#!" . $self->{shebang} . "\n" }
    else
    { $buffer .= "#!" . $shell->default_location . "\n" }
  }

  if($self->{echo_off} && ($shell->is_cmd || $shell->is_command))
  {
    $buffer .= '@echo off' . "\n";
  }

  foreach my $args (map { [@$_] } @{ $self->{commands} })
  {
    my $command = shift @$args;

    # rewrite set_path as set
    if($command eq 'set_path')
    {
      $command = 'set';
      my $name = shift @$args;
      $args = [$name, join $shell->is_win32 ? ';' : ':', @$args];
    }

    if($command eq 'set')
    {
      my($name, $value) = @$args;
      if($shell->is_c)
      {
        $value = _value_escape_csh($value);
        $buffer .= "setenv $name '$value';\n";
      }
      elsif($shell->is_bourne)
      {
        $value = _value_escape_sh($value);
        $buffer .= "export $name='$value';\n";
      }
      elsif($shell->is_cmd || $shell->is_command)
      {
        $value = _value_escape_win32($value);
        $buffer .= "set $name=$value\n";
      }
      else
      {
        die 'don\'t know how to "set" with ' . $shell->name;
      }
    }

    elsif($command eq 'append_path' || $command eq 'prepend_path')
    {
      my($name, @values) = @$args;
      if($shell->is_c)
      {
        my $value = join ':', map { _value_escape_csh($_) } @values;
        $buffer .= "[ \$?$name = 0 ] && setenv $name '$value' || ";
        if($command eq 'prepend_path')
        { $buffer .= "setenv $name '$value':\"\$$name\"" }
        else
        { $buffer .= "setenv $name \"\$$name\":'$value'" }
        $buffer .= ";\n";
      }
      elsif($shell->is_bourne)
      {
        my $value = join ':', map { _value_escape_sh($_) } @values;
        $buffer .= "if [ -n \"\$$name\" ] ; then\n";
        if($command eq 'prepend_path')
        { $buffer .= "  export $name='$value':\$$name;\n" }
        else
        { $buffer .= "  export $name=\$$name:'$value';\n" }
        $buffer .= "else\n";
        $buffer .= "  export $name='$value';\n";
        $buffer .= "fi;\n";
      }
      elsif($shell->is_cmd || $shell->is_command)
      {
        my $value = join ';', map { _value_escape_win32($_) } @values;
        $buffer .= "if defined $name (set ";
        if($command eq 'prepend_path')
        { $buffer .= "$name=$value;%$name%" }
        else
        { $buffer .= "$name=%$name%;$value" }
        $buffer .=") else (set $name=$value)\n";
      }
      else
      {
        die 'don\'t know how to "append_path" with ' . $shell->name;
      }
    }

    elsif($command eq 'comment')
    {
      if($shell->is_unix)
      {
        $buffer .= "# $_\n" for map { split /\n/, } @$args;
      }
      elsif($shell->is_cmd || $shell->is_command)
      {
        $buffer .= "rem $_\n" for map { split /\n/, } @$args;
      }
      else
      {
        die 'don\'t know how to "comment" with ' . $shell->name;
      }
    }
  }

  $buffer;
}

=head2 $config-E<gt>generate_file( $shell, $filename )

Generate shell configuration code for the given shell
and write it to the given file.  $shell is an instance 
of L<Shell::Guess>.  If there is an IO error it will throw
an exception.

=cut

sub generate_file
{
  my($self, $shell, $filename) = @_;
  use autodie;
  open my $fh, '>', $filename;
  print $fh $self->generate($shell);
  close $fh;
}

# TODO alias
# TODO PowerShell

1;

__END__

=head1 CAVEATS

The test suite tests this module's output against the actual
shells that should understand them, if they can be found in
the path.  You can generate configurations for shells which
are not available (for example C<cmd.exe> configurations from UNIX or
bourne configurations under windows), but the test suite only tests
them if they are found during the build of this module.

There are probably more clever or prettier ways to 
append/prepend path environment variables as I am not a shell
programmer.  Patches welcome.

Only UNIX and Windows are supported so far.  Patches welcome.

=cut
