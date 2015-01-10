package
  TestLib;

use strict;
use warnings;
use File::Spec;
use File::Temp qw( tempdir );
use Test::More;
use Shell::Guess;

my $sep = $^O eq 'MSWin32' ? ';' : ':';

sub shell_is_okay
{
  my($shell, $full_path) = @_;
  
  if($shell eq 'fish' && -x $full_path)
  {
    require IPC::Open3;
    my $pid = IPC::Open3::open3(\*IN, \*OUT, \*ERR, $full_path, '--version');
    waitpid $pid, 0;
    while(<ERR>) { note $_ }
    return $? == 0;
  }
  elsif($shell eq 'jsh' && -x $full_path)
  {
    require IPC::Open3;
    my $pid = IPC::Open3::open3(\*IN, \*OUT, \*ERR, $full_path, '-c', 'true');
    waitpid $pid, 0;
    while(<ERR>) { note $_ }
    return $? == 0;
  }
  
  return 1 if -x $full_path;
}

sub main::find_shell
{
  my $shell = shift;
  #return if $shell eq 'powershell.exe' && $^O eq 'cygwin';
  return $shell if $shell eq 'cmd.exe' && $^O eq 'MSWin32' && Win32::IsWinNT();
  return $shell if $shell eq 'command.com' && $^O eq 'MSWin32';
  foreach my $path (split $sep, $ENV{PATH})
  {
    my $full = File::Spec->catfile($path, $shell);
    return $full if shell_is_okay($shell, $full);
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
  tcsh             => 'tc_shell',
  csh              => 'c_shell',
  'bsd-csh'        => 'c_shell',
  bash             => 'bash_shell',
  sh               => 'bourne_shell',
  zsh              => 'z_shell',
  'command.com'    => 'command_shell',
  'cmd.exe'        => 'cmd_shell',
  ksh              => 'korn_shell',
  '44bsd-csh'      => 'c_shell',
  jsh              => 'bourne_shell',
  'powershell.exe' => 'power_shell',
  'fish'           => 'fish_shell',
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
  $fn .= ".ps1" if $shell->is_power;
  $fn = File::Spec->catfile($dir, $fn);
  unlink $fn if -e $fn;
  do {
    open(my $fh, '>', $fn) || die "unable to write to $fn $!";
    if($shell->is_unix)
    {
      print $fh "#!$shell_path";
      print $fh " -f" if $shell->is_c;
      print $fh "\n";
    }
    print $fh "\@echo off\n" if $shell->is_command || $shell->is_cmd;
    print $fh "shopt -s expand_aliases\n" if $shell_path =~  /bash(.exe)?$/;
    eval { print $fh $config->generate($shell) };
    diag $@ if $@;
    if(@_)
    {
      print $fh "$_\n" for @_;
    }
    else
    {
      my $perl_exe = $^X;
      $perl_exe = Cygwin::posix_to_win_path($perl_exe)
        if $^O eq 'cygwin' && $fn =~ /\.(bat|cmd|ps1)$/;
      print $fh "$perl_exe ", File::Spec->catfile($dir, 'dump.pl'), "\n";
      close $fn;
    }
    print $fh "exit\n" if $shell->is_power;
  };
  
  chmod 0700, $fn;

  my $VAR1;
  my $output;
  if($shell->is_unix)
  {
    #diag `cat $fn`;
    if($shell->is_c)
    {
      $output = `$shell_path -f $fn`;
    }
    else
    {
      $output = `$shell_path $fn`;
    }
  }
  elsif($shell->is_power)
  {
    #diag `cat $fn`;
    my $fn2 = $fn;
    $fn2 = Cygwin::posix_to_win_path($fn) if $^O eq 'cygwin';
    $fn2 =~ s{\\}{/}g;
    $output = `$shell_path -ExecutionPolicy RemoteSigned -InputFormat none -NoProfile -File $fn2`;
  }
  else
  {
    $output = `$fn`;
  }
  
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

sub main::bad_fish
{
  my $path = shift;
  my $dir = File::Spec->catdir(tempdir( CLEANUP => 1 ), qw( one two three ));
  
  require IPC::Open3;
  my $pid = IPC::Open3::open3(\*IN, \*OUT, \*ERR, $path, -c => "setenv PATH \$PATH $dir");
  waitpid $pid, $?;
  
  my $str = do { local $/; <ERR> };
  #diag "str = \"$str\"";
  
  $? != 0;
}

1;
