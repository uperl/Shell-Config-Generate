use lib 't/lib';
use Test2::V0 -no_srand => 1;
use Shell::Config::Generate;
use TestLib;

tempdir();

my $config = eval { Shell::Config::Generate->new };
  
isa_ok $config, 'Shell::Config::Generate';

my $ret = eval { $config->set( FOO_SIMPLE_SET => 'bar' ) };
diag $@ if $@;
isa_ok $ret, 'Shell::Config::Generate';

$config->set( FOO_ESCAPE1 => '!@#$%^&*()_+-={}|[]\\;:<>?,./~`' );
$config->set( FOO_ESCAPE2 => "'" );
$config->set( FOO_ESCAPE3 => '"' );
$config->set( FOO_NEWLINE => "\n" );
$config->set( FOO_TAB     => "\t" );

foreach my $shell (qw( tcsh csh bsd-csh bash sh zsh cmd.exe command.com ksh 44bsd-csh jsh powershell.exe fish ))
{
  subtest $shell => sub {
    my $shell_path = find_shell($shell);
    skip_all "no $shell found" unless defined $shell_path;

    my $env = get_env($config, $shell, $shell_path);

    is $env->{FOO_SIMPLE_SET}, 'bar',                             "[$shell]".'FOO_SIMPLE_SET = bar';
    is $env->{FOO_ESCAPE1},    '!@#$%^&*()_+-={}|[]\\;:<>?,./~`', "[$shell]".'FOO_ESCAPE1    = !@#$%^&*()_+-={}|[]\\;:<>?,./~`';
    is $env->{FOO_ESCAPE2},    "'",                               "[$shell]".'FOO_ESCAPE2    = \'';
    is $env->{FOO_ESCAPE3},    '"',                               "[$shell]".'FOO_ESCAPE3    = "';
    is $env->{FOO_TAB},        "\t",                              "[$shell]".'FOO_TAB        = \t';
    
    SKIP: {
    skip "not sure how to escape new line for fish shell", 1 if $shell eq 'fish';
    is $env->{FOO_NEWLINE},    "\n",                              "[$shell]".'FOO_NEWLINE    = \n';
    }
    
  }
}

done_testing;
