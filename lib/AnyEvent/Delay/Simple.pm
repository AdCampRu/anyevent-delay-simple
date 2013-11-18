package AnyEvent::Delay::Simple;

use strict;
use warnings;

use AnyEvent;

use parent 'Exporter';


our @EXPORT = qw(delay);


our $VERSION = '0.01';


sub delay {
	my $cb = pop();
	my $cv = AE::cv;

	$cv->begin;
	_delay_step(@_, $cv);
	$cv->cb($cb);
	$cv->end();

	return;
}

sub _delay_step {
	my ($cv) = pop();
	my ($subs, $err) = @_;

	my $sub = shift(@$subs);

	return unless $sub;

	$cv->begin();
	AE::postpone {
		if ($err) {
			eval {
				$sub->();
			};
			if ($@) {
				AE::log error => $@;
				$cv->cb($err);
			}
			else {
				_delay_step($subs, $err, $cv);
			}
		}
		else {
			$sub->();
			_delay_step($subs, $err, $cv);
		}
		$cv->end();
	};

	return;
}


1;
