package Shell::Config::Generate;

use strict;
use warnings;

# ABSTRACT: Portably generate config for any shell
# VERSION

sub new
{
  my($class) = @_;
  bless { commands => [] }, $class;
}

sub set
{
  my($self, $name, $value) = @_;

  push $self->{commands}, ['set', $name, $value];

  $self;
}

sub comment
{
  my($self, @comments) = @_;

  push $self->{commands}, ['comment', $_] for @comments;

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

sub generate
{
  my($self, $shell) = @_;

  my $buffer = '';

  foreach my $args (map { [@$_] } @{ $self->{commands} })
  {
    my $command = shift @$args;

    if($command eq 'set')
    {
      my($name, $value) = map { $_ . '' } @$args;
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
      else
      {
        # FIXME
        die 'don\'t know how to "set" with ' . $shell->name;
      }
    }

    elsif($command eq 'comment')
    {
      if($shell->is_unix)
      {
        $buffer .= "# $_\n" for map { split /\n/, } @$args;
      }
      else
      {
        # FIXME
        die 'don\'t know how to "comment" with ' . $shell->name;
      }
    }
  }

  $buffer;
}

1;
