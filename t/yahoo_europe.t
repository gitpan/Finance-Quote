#!/usr/bin/perl -w
use strict;
use Test::More;
use Finance::Quote;

if (not $ENV{ONLINE_TEST}) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 34;

# Test Yahoo_europe functions.

my $q      = Finance::Quote->new();
my $year   = (localtime())[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->yahoo_europe("UG.PA","BOGUS.L");
ok(%quotes);

# Check the nav values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"UG.PA","last"} > 0);
ok(length($quotes{"UG.PA","name"}) > 0);
ok($quotes{"UG.PA","success"});
ok($quotes{"UG.PA", "currency"} eq "EUR");
ok(substr($quotes{"UG.PA","isodate"},0,4) == $year ||
   substr($quotes{"UG.PA","isodate"},0,4) == $lastyear);
ok(substr($quotes{"UG.PA","date"},6,4) == $year ||
   substr($quotes{"UG.PA","date"},6,4) == $lastyear);

# Make sure we don't have spurious % signs.

ok($quotes{"UG.PA","p_change"} !~ /%/);

# Check that a bogus stock returns no-success.
ok(! $quotes{"BOGUS","success"});

# London stocks can be returned in a variety of currencies

my %londonquotes = $q->fetch("yahoo_europe","RDSB.L");
ok($londonquotes{"RDSB.L","success"});
ok($londonquotes{"RDSB.L","currency"} eq "GBP");
ok(($londonquotes{"RDSB.L","currency"} eq "GBP") &&
   !defined($londonquotes{"RDSB.L","currency_set_by_fq"}));

%londonquotes = $q->fetch("yahoo_europe","CCR.L");
ok($londonquotes{"CCR.L","success"});
ok($londonquotes{"CCR.L","currency"} eq "EUR");
ok(($londonquotes{"CCR.L","currency"} eq "EUR") &&
   !defined($londonquotes{"CCR.L","currency_set_by_fq"}));

# Copenhangen stocks should be returned in Danisk Krone (DKK).

my %copenhagenquotes = $q->fetch("yahoo_europe","TDC.CO");
ok($copenhagenquotes{"TDC.CO","success"});
ok($copenhagenquotes{"TDC.CO","currency"} eq "DKK");
ok(($copenhagenquotes{"TDC.CO","currency"} eq "DKK") &&
   !defined($copenhagenquotes{"TDC.CO","currency_set_by_fq"}));

# Two stocks from the German XETRA.  One in EUR and one in USD.

my %xetraquotes = $q->fetch("yahoo_europe","DBK.DE", "ERM.DE");
ok($xetraquotes{"DBK.DE","success"});
ok($xetraquotes{"DBK.DE","currency"} eq "EUR");
ok(($xetraquotes{"DBK.DE","currency"} eq "EUR") &&
   !defined($xetraquotes{"DBK.DE","currency_set_by_fq"}));

# a stock from the Belgium Euronext market.

my %belgiumquotes = $q->fetch("yahoo_europe","SOLB.BR");
ok($belgiumquotes{"SOLB.BR","success"});
ok($belgiumquotes{"SOLB.BR","currency"} eq "EUR");
ok(($belgiumquotes{"SOLB.BR","currency"} eq "EUR") &&
   !defined($belgiumquotes{"SOLB.BR","currency_set_by_fq"}));
ok($belgiumquotes{"SOLB.BR","last"}>=50); # this expected trades around 60-200 EUR
ok($belgiumquotes{"SOLB.BR","last"}<=200);

# Check if close is between year_range for LTI.L (expressed in GBp) for checking if conversion is correct
my %ltiquotes = $q->fetch("yahoo_europe","LTI.L");
ok($ltiquotes{"LTI.L","success"});
my ($min,$max) = (50,50000); # change this if quotes are not supposed to be in this range anymore
if ($ltiquotes{"LTI.L","year_range"}=~ m/([\d\.]+)\s*-\s*([\d\.]+)/) {
  my ($year_low,$year_high) = ($1,$2) ;
  ok (($year_low >= $min) && ($year_high <= $max));
  # print "$year_low - $year_high\n";
}
ok (($ltiquotes{"LTI.L","close"} >= $min) && ($ltiquotes{"LTI.L","close"} <= $max));

# check that A0GFY7.SG returns correctly the currency (reported by GnuCash user)
%xetraquotes = $q->fetch("yahoo_europe","A0GFY7.SG");
ok($xetraquotes{"A0GFY7.SG","success"});
ok($xetraquotes{"A0GFY7.SG","currency"} eq "EUR");
ok(($xetraquotes{"A0GFY7.SG","currency"} eq "EUR") &&
   !defined($xetraquotes{"A0GFY7.SG","currency_set_by_fq"}));

TODO: {
    # Yahoo does not provide retrieval of ^DJI.US quotes since it lost
    # license for it. ^DJI can only be viewed on the html page anymore. We
    # need to write a HTML page scraper for this case
    local $TODO = "^DJI not returned by yahoo anymore.";
    %xetraquotes = $q->fetch("yahoo_europe","%40%5EDJI.US");
    ok($xetraquotes{"^DJI","success"});
    ok($xetraquotes{"^DJI","currency"} eq "USD");
}
