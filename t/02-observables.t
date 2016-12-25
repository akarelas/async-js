use v5.10;
use warnings;

use Test::More tests => 5;
use Test::Warnings;

use Async::JS qw/ Observable setTimeout /;

use Mojo::EventEmitter;
use EV;


# NEW & SUBSCRIBE
my @o_events;

my $o = Observable->new(sub {
	my ($observer) = @_;
	setTimeout(sub {
		$observer->next(100);
		$observer->complete;
	}, 1);
});

$o->subscribe(
	sub {
		my ($data) = @_;
		push @o_events, $data;
	},
	sub {
		my ($error) = @_;
		fail 'this should not be called';
	},
	sub {
		push @o_events, 'complete';
	}
);

setTimeout(sub {
	is_deeply(\@o_events, [100, 'complete'], 'new & subscribe work');
}, 1);


# FROM_ARRAY & MAP
my @o2_events;
my $o2 = Observable->from_array([10, 20, 30])->map(sub { $_[0] + 1 });
$o2->subscribe(
	sub {
		my ($data) = @_;
		push @o2_events, $data;
	},
	sub {
		my ($error) = @_;
		fail 'this should not be called';
	},
	sub {
		push @o2_events, 'complete';
	}
);
is_deeply(\@o2_events, [11, 21, 31, 'complete'], 'from_array and map work');

# FROM EVENT
my @o3_events;
my $emitter = Mojo::EventEmitter->new;
my $o3 = Observable->from_event($emitter, 'click');
$emitter->emit('click', 10, 20, 30);
my $unsubscribe = $o3->subscribe(
	sub {
		my ($data) = @_;
		push @o3_events, $data;
	},
	sub {
		my ($error) = @_;
		fail 'this should not be called';
	},
	sub {
		fail 'this should not be called';
	}
);
$emitter->emit('click');
$emitter->emit('click', 10);
$emitter->emit('click', 20, 30);
$unsubscribe->();
$emitter->emit('click', 40);
is_deeply \@o3_events, [
	[$emitter],
	[$emitter, 10],
	[$emitter, 20, 30],
], 'from_events works';

# MERGE_MAP
my @o4_events;
my $o4 = Observable->from_array([10, 20, 30])
			->merge_map(sub {
				my ($n) = @_;
				return Observable->from_array([$n, $n+1]);
			});
$o4->subscribe(
	sub {
		my ($data) = @_;
		push @o4_events, $data;
	},
	sub {
		my ($error) = @_;
		fail 'this should not be called';
	},
	sub {
		push @o4_events, 'complete';
	}
);
is_deeply \@o4_events, [10, 11, 'complete', 20, 21, 'complete', 30, 31, 'complete', 'complete'], 'merge_map works';

EV::run;
done_testing;
