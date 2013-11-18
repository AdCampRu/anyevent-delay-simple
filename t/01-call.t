#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;

use AnyEvent;
use AnyEvent::Delay::Simple;


local $ENV{PERL_ANYEVENT_LOG} = 'log=nolog';

my $cv = AE::cv;
my @res;

$cv->begin();
delay(
	[map { my $v = $_; sub { push(@res, $v); die() if $v == 5; } } 0 .. 9],
	sub { push(@res, -1); $cv->end() },
	sub { $cv->end(); }
);
$cv->begin();
delay(
	[map { my $v = $_; sub { push(@res, $v); } } 10 .. 19],
	sub { $cv->end(); }
);
$cv->wait();

cmp_bag \@res, [-1, 0 .. 5, 10 .. 19];


done_testing();
