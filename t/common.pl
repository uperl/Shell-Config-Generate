package
  TestLib;

use strict;
use warnings;
use File::Spec;
use File::Temp qw( tempdir );
use Test::More;
use Shell::Guess;

my $sep = $^O eq 'MSWin32' ? ';' : ':';

sub main::find_shell
{
  my $shell = shift;
  foreach my $path (split $sep, $ENV{PATH})
  {
    my $full = File::Spec->catfile($path, $shell);
    return $full if -x $full;
  }
  
  return;
}

my $dir = tempdir( CLEANUP => 1 );

do {
  my $fn = File::Spec->catfile($dir, 'dump.pl');
  open my $fh, '>', $fn;
  print $fh q{
    use strict;
    use warnings;
    use Data::Dumper;
    my %data = map { $_ => $ENV{$_} } grep /^FOO/, keys %ENV;
    print Dumper(\%data);
  };
  close $fh;
};

sub main::tempdir
{
  ok -d $dir, "tempdir = $dir";
  $dir;
}

my %shell = (
  tcsh => 'tc_shell',
  csh  => 'c_shell',
  bash => 'bash_shell',
  sh   => 'bourne_shell',
  zsh  => 'z_shell',
);

sub get_guess
{
  my $method = $shell{$_[0]};
  Shell::Guess->$method;
}

sub main::get_env
{
  my $config = shift;
  my $shell = get_guess(shift);
  my $shell_path = shift;
  
  my $fn = File::Spec->catfile($dir, "foo");
  unlink $fn if -e $fn;
  do {
    open(my $fh, '>', $fn) || die "unable to write to $fn $!";
    print $fh "#!$shell_path\n";
    eval { print $fh $config->generate($shell) };
    diag $@ if $@;
    print $fh "$^X ", File::Spec->catfile($dir, 'dump.pl'), "\n";
    close $fn;
  };
  
  chmod 0700, $fn;

  diag `cat $fn`;  
  my $VAR1;
  eval `$fn`;
  
  return $VAR1;
}

1;
