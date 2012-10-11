package Shell::Config::Generate;

use strict;
use warnings;

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
 export FOO='bar'
 export PERL5LIB='/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site'
 if [ -n "$PATH" ] ; then
   export PATH=$PATH:'/foo/bar/bin:/bar/foo/bin'
 else
   export PATH='/foo/bar/bin:/bar/foo/bin'
 fi

and this:

 $config->generate_file(Shell::Guess->c_shell, 'config.csh');

will generate a config.csh with this:

 # this is my config file
 setenv FOO 'bar'
 setenv PERL5LIB '/foo/bar/lib/perl5:/foo/bar/lib/perl5/perl5/site'
 if ( $?PATH ) then
   setenv PATH "$PATH":'/foo/bar/bin:/bar/foo/bin'
 else
   setenv PATH '/foo/bar/bin:/bar/foo/bin'
 endif

and this:

 $config->generate_file(Shell::Guess->cmd_shell, 'config.cmd');

will generate a config.cmd (Windows cmd.exe script) with this:

 rem this is my config file
 set FOO=bar
 set PERL5LIB=/foo/bar/lib/perl5;/foo/bar/lib/perl5/perl5/site
 if defined PATH (set PATH=%PATH%;/foo/bar/bin;/bar/foo/bin) else (set PATH=/foo/bar/bin;/bar/foo/bin)

=cut

sub new
{
  my($class) = @_;
  bless { commands => [], echo_off => 0 }, $class;
}

sub set
{
  my($self, $name, $value) = @_;

  push @{ $self->{commands} }, ['set', $name, $value];

  $self;
}

sub set_path
{
  my($self, $name, @list) = @_;

  push @{ $self->{commands} }, [ 'set_path', $name, @list ];

  $self;
}

sub append_path
{
  my($self, $name, @list) = @_;

  push @{ $self->{commands} }, [ 'append_path', $name, @list ]
    if @list > 0;

  $self;
}

sub prepend_path
{
  my($self, $name, @list) = @_;

  push @{ $self->{commands} }, [ 'prepend_path', $name, @list ]
    if @list > 0;

  $self;
}

sub comment
{
  my($self, @comments) = @_;

  push @{ $self->{commands} }, ['comment', $_] for @comments;

  $self;
}

sub shebang
{
  my($self, $location) = @_;
  $self->{shebang} = $location;
  $self;
}

sub echo_off
{
  my($self) = @_;
  $self->{echo_off} = 1;
  $self;
}

sub echo_on
{
  my($self) = @_;
  $self->{echo_off} = 0;
  $self;
}

sub _value_escape_csh
{
  my $value = shift . '';
  $value =~ s/([\n!])/\\$1/g;
  $value =~ s/(')/'"$1"'/g;
  $value;
}

sub _value_escape_sh
{
  my $value = shift . '';
  $value =~ s/(')/'"$1"'/g;
  $value;
}

sub _value_escape_win32
{
  my $value = shift . '';
  $value =~ s/%/%%/g;
  $value =~ s/([&^|<>])/^$1/g;
  $value =~ s/\n/^\n\n/g;
  $value;
}

sub generate
{
  my($self, $shell) = @_;

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
        $buffer .= "setenv $name '$value'\n";
      }
      elsif($shell->is_bourne)
      {
        $value = _value_escape_sh($value);
        $buffer .= "export $name='$value'\n";
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
        $buffer .= "if ( \$?$name ) then\n";
        if($command eq 'prepend_path')
        { $buffer .= "  setenv $name '$value':\"\$$name\"\n" }
        else
        { $buffer .= "  setenv $name \"\$$name\":'$value'\n" }
        $buffer .= "else\n";
        $buffer .= "  setenv $name '$value'\n";
        $buffer .= "endif\n";
      }
      elsif($shell->is_bourne)
      {
        my $value = join ':', map { _value_escape_sh($_) } @values;
        $buffer .= "if [ -n \"\$$name\" ] ; then\n";
        if($command eq 'prepend_path')
        { $buffer .= "  export $name='$value':\$$name\n" }
        else
        { $buffer .= "  export $name=\$$name:'$value'\n" }
        $buffer .= "else\n";
        $buffer .= "  export $name='$value'\n";
        $buffer .= "fi\n";
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

sub generate_file
{
  my($self, $shell, $filename) = @_;
  use autodie;
  open my $fh, '>', $filename;
  print $fh $self->generate($shell);
  close $fh;
}

# TODO alias

1;
