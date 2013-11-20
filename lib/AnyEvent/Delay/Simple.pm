package AnyEvent::Delay::Simple;

use strict;
use warnings;

use AnyEvent;

use parent 'Exporter';


our $VERSION = '0.04';


our @EXPORT = qw(delay);


sub import {
	my ($class, @args) = @_;

	if (grep { $_ && $_ eq 'ae' } @args) {
		no strict 'refs';
		*AE::delay = \&delay;
	}
	else {
		$class->export_to_level(1, @args);
	}
}

use DDP;
sub delay {
	my $fin = pop();
	my ($subs, $err);

	if (ref($_[0]) eq 'ARRAY') {
		$subs = shift();
		$err  = pop();
	}
	else {
		$err  = pop();
		$subs = \@_;
	}

	my $cv = AE::cv;

	$cv->begin();
	$cv->cb(sub {
		_delay_step([$fin], undef, [$cv->recv()], $cv);
	});
	_delay_step($subs, $err, $cv);
	$cv->end();

	return;
}

sub _delay_step {
	my $cv = pop();
	my ($subs, $err, $args) = @_;

	my $sub = shift(@$subs);

	unless (defined($args)) {
		$args = [];
	}
	unless ($sub) {
		$cv->send(@$args);

		return;
	}

	$cv->begin();
	AE::postpone {
		my @res;
		my $xcv = AE::cv;

		$xcv->begin();
		if ($err) {
			eval {
				$sub->($xcv, @$args);
			};
			if ($@) {
				AE::log error => $@;
				$cv->cb(sub {
					_delay_step([$err], undef, [$cv->recv()], $cv);
				});
				$cv->send(@$args);
				$cv->end();
				undef($xcv);
			}
			else {
				_delay_step_ex($subs, $err, $xcv, $cv);
			}
		}
		else {
			$sub->($xcv, @$args);
			_delay_step_ex($subs, $err, $xcv, $cv);
		}
	};

	return;
}

sub _delay_step_ex {
	my ($subs, $err, $xcv, $cv) = @_;

	my $cb = $xcv->cb();

	$xcv->cb(sub {
		$cb->() if $cb;
		_delay_step($subs, $err, [$xcv->recv()], $cv);
		$cv->end();
	});
	$xcv->end();

	return;
}


1;


__END__

=head1 NAME

AnyEvent::Delay::Simple - Manage callbacks and control the flow of events by AnyEvent

=head1 SYNOPSIS

    use AnyEvent::Delay::Simple;

    my $cv = AE::cv;
    delay(
        sub {
            say('1st step');
            shift->send('1st result'); # send data to 2nd step
        },
        sub {
            shift;
            say(@_);                   # receive data from 1st step
            say('2nd step');
            die();
        },
        sub {                          # never calls because 2nd step failed
            say('3rd step');
        },
        sub {                          # calls on error, at this time
            say('Fail: ' . $@);
            $cv->send();
        },
        sub {                          # calls on success, not at this time
            say('Ok');
            $cv->send();
        }
    );
    $cv->recv();

=head1 DESCRIPTION

AnyEvent::Delay::Simple manages callbacks and controls the flow of events for
AnyEvent. This module inspired by L<Mojo::IOLoop::Delay>.

=head1 FUNCTIONS

=head2 delay

    delay([\&step_1, ..., \&step_n], \&finish);
    delay([\&step_1, ..., \&step_n], \&error, \&finish);
    delay(\&step_1, ..., \&step_n, \&error, \&finish);

Runs the chain of callbacks, the first callback will run right away, and the
next one once the previous callback finishes. This chain will continue until
there are no more callbacks, or an error occurs in a callback. If an error
occurs in one of the steps, the chain will be break, and error handler will
call, if it's defined. Unless error handler defined, error is fatal. If last
callback finishes and no error occurs, finish handler will call.

Condvar and data from previous step passed as arguments to each callback or
handler. If an error occurs then input data of the failed callback passed to
the error handler. The data sends to the next step by using condvar's C<send()>
mrthod.

    sub {
        my $cv = shift();
        $cv->send('foo', 'bar');
    },
    sub {
        my ($cv, @args) = @_;
        # now @args is ('foo', 'bar')
    },

Condvar can be used to control the flow of events within step.

    sub {
        my $cv = shift();
        $cv->begin();
        $cv->begin();
        my $w1; $w1 = AE::timer 1.0, 0, sub { $cv->end(); undef($w1); };
        my $w2; $w2 = AE::timer 2.0, 0, sub { $cv->end(); undef($w2); };
        $cv->cb(sub { $cv->send('step finished'); });
    }

You may import this function into L<AE> namespace instead of current one. Just
use module with symbol C<ae>.

    use AnyEvent::Delay::Simple qw(ae);
    AE::delay(...);

=head1 SEE ALSO

L<AnyEvent>, L<AnyEvent::Delay>, L<Mojo::IOLoop::Delay>.

=head1 SUPPORT

=over 4

=item Repository

L<http://github.com/AdCampRu/anyevent-delay-simple>

=item Bug tracker

L<http://github.com/AdCampRu/anyevent-delay-simple/issues>

=back

=head1 AUTHOR

Denis Ibaev C<dionys@cpan.org> for AdCamp.ru.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See L<http://dev.perl.org/licenses/> for more information.

=cut
