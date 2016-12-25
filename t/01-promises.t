use v5.10;
use warnings;

use Test::More tests => 21;
use Test::Warnings;

use Async::JS qw/ setTimeout setInterval clearInterval Promise throw /;
use EV;


Promise->new(sub {
	my ($resolve, $reject) = @_;
	pass 'promise code executes';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$resolve->(100);
})->then(sub {
	my ($n) = @_;
	is $n, 100, 'simple resolve and then';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 10);
})->then(sub {
	my ($n) = @_;
	is $n, 100, 'timeout resolve';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 10);
})->then(sub {
	my ($n) = @_;
	return $n * 2;
})->then(sub {
	my ($n) = @_;
	is $n, 200, 'chained thens';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 10);
})->then(
)->then(sub {
	my ($n) = @_;
	is $n, 100, 'behaves well with missing middle onFulfilled function';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	throw 'alex';
})->then()->then(
	undef,
	sub {
		my ($r) = @_;
		is $r, "alex", 'throw in promise produces rejection';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$resolve->(100);
})->then(
	sub {
		my ($val) = @_;
		throw 'john';
	}
)->then(
	undef,
	sub {
		my ($r) = @_;
		is $r, "john", 'throw in then produces rejection';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	die 'alex';
})->then()->then(
	undef,
	sub {
		my ($r) = @_;
		like $r, qr/\Aalex at \S+ line \d+\.\s\z/, 'die in promise produces correct reason';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	die {a => 1, b => 2};
})->then()->then(
	undef,
	sub {
		my ($r) = @_;
		is_deeply $r, {a => 1, b => 2}, 'die <object> in promise produces correct reason';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	my $new_p = Promise->new(sub {
		my ($resolve, $reject) = @_;
		$resolve->(123);
	});
	$resolve->($new_p);
})->then(sub {
	my ($val) = @_;
	is $val, 123, 'promise resolves to promise';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	my $new_p = Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->(123);
		}, 10);
	});
	$resolve->($new_p);
})->then(sub {
	my ($val) = @_;
	is $val, 123, 'promise resolves to promise async';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$resolve->(100);
})->then(sub {
	my ($val) = @_;
	return Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->($val * 2);
		}, 10);
	});
})->then(sub {
	my ($val) = @_;
	is $val, 200, 'then returns promise async';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$reject->('peter');
})->then(
	undef,
	sub {
		my ($reason) = @_;
		is $reason, 'peter', 'a promise may simply reject';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$reject->('peter');
	}, 10);
})->then(
	undef,
	sub {
		my ($reason) = @_;
		is $reason, 'peter', 'a promise may simply reject async';
	}
);

# ALL
my @ps;
for my $i (1..10) {
	my $j = $i;
	push @ps, Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->($j * 10);
		}, 100);
	});
}
Promise->all(\@ps)->then(
	sub {
		my ($ret) = @_;
		is_deeply $ret, [10, 20, 30, 40, 50, 60, 70, 80, 90, 100], '->all(10 promises)';
	},
	sub {
		fail;
	},
);

my @events_1;
Promise->all([
	Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->(20);
		}, 100);
	}),
	Promise->reject(10),
])->then(
	sub { push @events_1, $_[0]; },
	sub { push @events_1, "error $_[0]"; },
);

setTimeout(sub {
	is_deeply \@events_1, ['error 10'], 'all with rejection';
}, 20);
setTimeout(sub {
	is_deeply \@events_1, ['error 10'], 'all with rejection';
}, 110);

# RACE
my $result_1;
Promise->race([
	Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->(20);
		}, 50);
	}),
	Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->(10);
		}, 1);
	}),
])->then(
	sub { $result_1 = $_[0]; },
	sub { fail; },
);
setTimeout(sub {
	is $result_1, undef, 'race 1';
});
setTimeout(sub {
	is $result_1, 10, 'race 2';
}, 30);
setTimeout(sub {
	is $result_1, 10, 'race 3';
}, 100);

# CANCEL
my $p = Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 100);
});
$p->then(
	sub { fail; },
	sub { fail; },
);
setTimeout(sub {
	$p->cancel;
}, 1);


EV::run;
