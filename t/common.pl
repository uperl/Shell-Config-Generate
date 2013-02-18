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
  return $shell if $shell eq 'cmd.exe' && $^O eq 'MSWin32' && Win32::IsWinNT();
  return $shell if $shell eq 'command.com' && $^O eq 'MSWin32';
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
  #diag `cat $fn`;
};

sub main::tempdir
{
  ok -d $dir, "tempdir = $dir";
  $dir;
}

my %shell = (
  tcsh          => 'tc_shell',
  csh           => 'c_shell',
  bash          => 'bash_shell',
  sh            => 'bourne_shell',
  zsh           => 'z_shell',
  'command.com' => 'command_shell',
  'cmd.exe'     => 'cmd_shell',
  ksh           => 'korn_shell',
  '44bsd-csh'   => 'c_shell',
  jsh           => 'bourne_shell',
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
  
  my $fn = 'foo';
  $fn .= ".bat" if $shell->is_command;
  $fn .= ".cmd" if $shell->is_cmd;
  $fn = File::Spec->catfile($dir, $fn);
  unlink $fn if -e $fn;
  do {
    open(my $fh, '>', $fn) || die "unable to write to $fn $!";
    print $fh "#!$shell_path\n" if $shell->is_unix;
    print $fh "\@echo off\n" if $shell->is_command || $shell->is_cmd;
    eval { print $fh $config->generate($shell) };
    diag $@ if $@;
    print $fh "$^X ", File::Spec->catfile($dir, 'dump.pl'), "\n";
    close $fn;
  };
  
  chmod 0700, $fn;

  my $VAR1;
  my $output = $shell->is_unix ? `$shell_path $fn` : `$fn`;

  my $fail = 0;  
  if ($? == -1)
  {
    diag "failed to execute: $!\n";
    $fail = 1;
  }
  elsif ($? & 127) {
    diag "child died with signal ", $? & 127;
    $fail = 1;
  }
  elsif($? >> 8)
  {
    diag "child exited with value ", $? >> 8;
    $fail = 1;
  }
  
  if($fail)
  {
    diag "[src]\n" . `cat $fn`;
    diag "[out]\n$output";
  }
  
  eval $output;
  
  return $VAR1;
}

1;
