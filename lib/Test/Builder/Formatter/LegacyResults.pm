package Test::Builder::Formatter::LegacyResults;
use strict;
use warnings;

use parent 'Test::Builder::Formatter';

use Test::Builder::Threads;

sub init {
    my $self = shift;
    $self->reset;
}

sub reset {
    my $self = shift;

    $self->{Test_Results} = &share( [] );
    $self->{Curr_Test}    = 0;

    &share(\$self->{Curr_Test});

    return;
}

sub summary {
    my($self) = shift;
    return map { $_->{'ok'} } @{ $self->{Test_Results} };
}

sub details {
    my $self = shift;
    return @{ $self->{Test_Results} };
}

sub current_test {
    my ($self, $tb, $num) = @_;

    lock( $self->{Curr_Test} );
    if( defined $num ) {
        my $delta = $num - $self->{Curr_Test};
        $self->{Curr_Test} = $num;

        $tb->stream->tests_run($delta);
        $tb->tap->test_number($delta) if $tb->tap;

        # If the test counter is being pushed forward fill in the details.
        my $test_results = $self->{Test_Results};
        if( $num > @$test_results ) {
            my $start = @$test_results ? @$test_results : 0;
            for( $start .. $num - 1 ) {
                $test_results->[$_] = &share(
                    {
                        'ok'      => 1,
                        actual_ok => undef,
                        reason    => 'incrementing test number',
                        type      => 'unknown',
                        name      => undef
                    }
                );
            }
        }
        # If backward, wipe history.  Its their funeral.
        elsif( $num < @$test_results ) {
            $#{$test_results} = $num - 1;
        }
    }
    return $self->{Curr_Test};
}

sub sanity_check {
    my $self = shift;
    my ($tb) = @_;

    $tb->_whoa( $self->{Curr_Test} < 0, 'Says here you ran a negative number of tests!' );

    $tb->_whoa(
        $self->{Curr_Test} != @{ $self->{Test_Results} },
        'Somehow you got a different number of results than tests ran!'
    );

    return;
}

sub ok {
    my $self = shift;
    my ($item) = @_;

    my $result = &share( {} );

    lock $self->{Curr_Test};
    $self->{Curr_Test}++;

    $result->{ok} = $item->bool;
    $result->{actual_ok} = $item->real_bool;

    my $name = $item->name;
    if(defined $name) {
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        $result->{name} = $name;
    }
    else {
        $result->{name} = '';
    }

    if($item->skip && ($item->in_todo || $item->todo)) {
        $result->{type} = 'todo_skip',
        $result->{reason} = $item->skip || $item->todo;
    }
    elsif($item->in_todo || $item->todo) {
        $result->{reason} = $item->todo;
        $result->{type}   = 'todo';
    }
    elsif($item->skip) {
        $result->{reason} = $item->skip;
        $result->{type}   = 'skip';
    }
    else {
        $result->{reason} = '';
        $result->{type}   = '';
    }

    $self->{Test_Results}[ $self->{Curr_Test} - 1 ] = $result;
}

1;
