use strict;
use warnings;
use File::Spec;
use Test::More tests => 1;

diag "info";

my $found_square_bracket = 0;
my $found_test = 0;

foreach my $path (split(($^O eq 'MSWin32' ? ';' : ':'), $ENV{PATH}))
{
  diag "PATH = $path";
    
  if(-x File::Spec->catfile($path, '['))
  {
    diag "  has $path / [";
    $found_square_bracket = 1;
  }
  
  if(-x File::Spec->catfile($path, 'test'))
  {
    diag "  has $path / test";
    $found_test = 1;
  }
}


unless($found_square_bracket)
{
  diag "DID NOT FIND [, CSH TESTS WILL LIKELY FAIL";
}

unless($found_test)
{
  diag "did not find test";
}

pass 'okay';
