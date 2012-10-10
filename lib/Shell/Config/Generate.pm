package Shell::Config::Generate;

use strict;
use warnings;

# ABSTRACT: Portably generate config for any shell
# VERSION

sub new
{
  my($class) = @_;
  bless { commands => [], echooff => 0 }, $class;
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

sub echooff
{
  my($self) = @_;
  $self->{echooff} = 1;
  $self;
}

sub echoon
{
  my($self) = @_;
  $self->{echooff} = 0;
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

  if($self->{echooff} && ($shell->is_cmd || $shell->is_command))
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
        $buffer .= "if defined $name (set $name=%$name%;$value) else (set $name=$value)\n";
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

# TODO alias

1;
