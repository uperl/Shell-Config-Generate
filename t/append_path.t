use strict;
use warnings;
use constant tests_per_shell => 2;
use constant number_of_shells => 11;
use Test::More tests => (tests_per_shell * number_of_shells) + 3;
use Shell::Config::Generate;
use FindBin ();
use Test::Differences;

require "$FindBin::Bin/common.pl";

tempdir();

my $config = eval { Shell::Config::Generate->new };
  
isa_ok $config, 'Shell::Config::Generate';

$ENV{FOO_PATH1} = join ':', 'foo:bar';

my $ret = eval { $config->append_path( FOO_PATH1 => 'baz' ) };
diag $@ if $@;
isa_ok $ret, 'Shell::Config::Generate';

delete $ENV{FOO_PATH2};

$config->append_path( FOO_PATH2 => qw( foo bar baz ) );

foreach my $shell (qw( tcsh csh bsd-csh bash sh zsh cmd.exe command.com ksh 44bsd-csh jsh ))
{
  my $shell_path = find_shell($shell);
  SKIP: {
    skip "no $shell found", tests_per_shell unless defined $shell_path;

    my $env = get_env($config, $shell, $shell_path);

    eq_or_diff [split /;|:/, $env->{FOO_PATH1}], [qw( foo bar baz )], "[$shell] FOO_PATH1 = foo bar baz";
    eq_or_diff [split /;|:/, $env->{FOO_PATH2}], [qw( foo bar baz )], "[$shell] FOO_PATH2 = foo bar baz";
  }
}

