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
	sub { push(@res, -1); $cv->end(); },
	sub { $cv->end(); }
);
$cv->begin();
delay(
	[map { my $v = $_; sub { push(@res, $v); } } 10 .. 19],
	sub { $cv->end(); }
);
$cv->wait();
cmp_bag \@res, [-1, 0 .. 5, 10 .. 19];

$cv = AE::cv;
$cv->begin();
delay([
	sub { 1; },
	sub { is scalar(@_), 1; is $_[0], 1; return (1, 2, 3); },
	sub { is scalar(@_), 3; cmp_deeply \@_, [1, 2, 3]; 2; }],
	sub { $cv->end(); },
	sub { is scalar(@_), 1; is $_[0], 2; $cv->end(); }
);
$cv->wait();

$cv = AE::cv;
delay([
	sub { 1; },
	sub { is scalar(@_), 1; is $_[0], 1; return (1, 2, 3); },
	sub { die(); }],
	sub { is scalar(@_), 3; cmp_deeply \@_, [1, 2, 3]; $cv->send(1); },
	sub { $cv->send(2); }
);
is $cv->recv(), 1;

eval { AE::delay(); };
like $@, qr/^Undefined subroutine/;


done_testing();
