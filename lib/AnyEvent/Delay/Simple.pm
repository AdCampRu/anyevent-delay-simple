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


__END__

=head1 NAME

AnyEvent::Delay::Simple - Manage callbacks and control the flow of events by
AnyEvent

=head1 SYNOPSIS

    use AnyEvent::Delay::Simple;

    my $cv = AE::cv;

    delay([
        sub { say('1st step'); },
        sub { say('2nd step'); die(); },
        # never calls because 2nd step failed
        sub { say('3rd step'); }],
        # calls on error
        sub { say('Fail: ' . $@); $cv->send(); },
        # calls on success
        sub { say('Ok'); $cv->send(); }
    );
    $cv->recv();

=head1 DESCRIPTION

AnyEvent::Delay::Simple manages callbacks and controls the flow of events for
AnyEvent. This module inspired by L<Mojo::IOLoop::Delay>.

=head1 FUNCTIONS

=head2 delay

    delay(\@steps, $finish);
    delay(\@steps, $error, $finish);

Runs the chain of callbacks, the first callback will run right away, and the
next one once the previous callback finishes. This chain will continue until
there are no more callbacks, or an error occurs in a callback. If an error
occurs in one of the steps, the chain will be break, and error handler will
call if it's defined. Unless error handler defined, error is fatal. If last
callback finishes and no error occurs, finish handler will call.

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
