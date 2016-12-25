package Async::JS::AsyncAwait;

use v5.10;
use warnings;

use Coro ();
use Coro::EV ();

use Async::JS::Exception 'throw';


sub await {
	my ($promise) = @_;
	my $result_channel = Coro::Channel->new;
	Coro::async {
		$promise->then(
			sub {
				my ($value) = @_;
				$result_channel->put({value => $value});
			},
			sub {
				my ($error) = @_;
				$result_channel->put({error => $error});
			}
		);
	};
	my $ret = $result_channel->get;
	if (exists $ret->{value}) {
		return $ret->{value};
	} else {
		throw $ret->{error};
	}
};

sub async_sub (&) {
	my $sub = shift;
	return sub {
		my @params = @_;
		return Async::JS::Promise->new(sub {
			my ($resolve, $reject) = @_;
			Coro::async {
				my $ret;
				my $success = eval { $ret = $sub->(@params); 1 };
				my $e = $@;
				if ($success) {
					$resolve->($ret);
				} else {
					$reject->($e);
				}
			}->cede_to;
		});
	};
};


1;
