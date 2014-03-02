#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 8;

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->ftfunds("GB0031835118","GB0030880255","GB0003865176","BOGUS");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"GB0031835118","last"} > 0);
ok($quotes{"GB0031835118","success"});

ok($quotes{"GB0030880255","last"} > 0);
ok($quotes{"GB0030880255","success"});

ok($quotes{"GB0003865176","last"} > 0);
ok($quotes{"GB0003865176","success"});

# Check that bogus stocks return failure:

ok(! $quotes{"BOGUS","success"});
