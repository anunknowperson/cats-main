package CATS::Problem;

use strict;
use warnings;


sub apply_test_rank
{
    my ($v, $rank) = @_;
    $v ||= '';
    $v =~ s/%n/$rank/g;
    $v =~ s/%0n/sprintf("%02d", $rank)/eg;
    $v =~ s/%%/%/g;
    $v;
}


sub validate_test
{
    my ($test) = @_;
    defined $test->{in_file} || $test->{generator_id}
        or return 'No input source';
    defined $test->{in_file} && $test->{generator_id}
        and return 'Both input file and generator';
    ($test->{param} || $test->{gen_group}) && !$test->{generator_id}
        and return 'Parameters without generator';
    defined $test->{out_file} || $test->{std_solution_id}
        or return 'No output source';
    defined $test->{out_file} && $test->{std_solution_id}
        and return 'Both output file and standard solution';
    undef;
}


sub set_test_attr
{
    (my CATS::Problem $self, my $test, my $attr, my $value) = @_;
    defined $value or return;
    defined $test->{$attr}
        and return $self->error("Rederined attribute '$attr' for test #$test->{rank}");
    $test->{$attr} = $value;
}


sub add_test
{
    (my CATS::Problem $self, my $atts, my $rank) = @_;
    $rank =~ /^\d+$/ && $rank > 0 && $rank < 1000
        or $self->error("Bad rank: '$rank'");
    my $t = $self->{tests}->{$rank} ||= { rank => $rank };
    $self->set_test_attr($t, 'points', $atts->{points});
    push @{$self->{current_tests}}, $t;
}


sub parse_test_rank
{
    (my CATS::Problem $self, my $rank_spec) = @_;
    my $result = [];
    # Последовательность диапазонов через запятую, например '1,5-10,2'
    for (split ',', $rank_spec)
    {
        $_ =~ /^\s*(\d+)(?:-(\d+))?\s*$/
            or $self->error("Bad element '$_' in rank spec '$rank_spec'");
        my ($from, $to) = ($1, $2 || $1);
        $from <= $to or $self->error("from > to in rank spec '$rank_spec'");
        push @$result, ($from..$to);
    }
    $result;
}


sub start_tag_Test
{
    (my CATS::Problem $self, my $atts) = @_;
    $self->{current_tests} = [];
    $self->add_test($atts, $_) for @{$self->parse_test_rank($atts->{rank})};
}


sub start_tag_TestRange
{
    (my CATS::Problem $self, my $atts) = @_;
    $atts->{from} <= $atts->{to}
        or $self->error('TestRange.from > TestRange.to');
    $self->{current_tests} = [];
    $self->add_test($atts, $_) for ($atts->{from}..$atts->{to});
    $self->warning("Deprecated tag 'TestRange', use 'Test' instead");
}


sub end_tag_Test
{
    my CATS::Problem $self = shift;
    undef $self->{current_tests};
}


sub start_tag_In
{
    (my CATS::Problem $self, my $atts) = @_;
    
    my @t = @{$self->{current_tests}};

    if (defined $atts->{src})
    {
        for (@t)
        {
            my $src = apply_test_rank($atts->{'src'}, $_->{rank});
            my $member = $self->{zip}->memberNamed($src)
                or $self->error("Invalid test input file reference: '$src'");
            $self->set_test_attr($_, 'in_file', $self->read_member($member, $self->{debug}));
        }
    }
    if (defined $atts->{'use'})
    {
        my $gen_group = $atts->{genAll} ? ++$self->{gen_group} : undef;
        for (@t)
        {
            my $use = apply_test_rank($atts->{'use'}, $_->{rank});
            $self->set_test_attr($_, 'generator_id',
                $self->get_imported_id($use) || $self->get_named_object($use)->{id});
            # TODO
            $self->set_test_attr($_, 'gen_group', $gen_group);
        }
    }
    if (defined $atts->{param})
    {
        for (@t)
        {
            $self->set_test_attr($_, 'param', apply_test_rank($atts->{param}, $_->{rank}));
        }
    }
    
}


sub start_tag_Out
{
    (my CATS::Problem $self, my $atts) = @_;

    my @t = @{$self->{current_tests}};

    if (defined $atts->{src})
    {
        for (@t)
        {
            my $src = apply_test_rank($atts->{'src'}, $_->{rank});
            my $member = $self->{zip}->memberNamed($src)
                or $self->error("Invalid test output file reference: '$src'");
            $self->set_test_attr($_, 'out_file', $self->read_member($member, $self->{debug}));
        }
    }
    if (defined $atts->{'use'})
    {
        for (@t)
        {
            my $use = apply_test_rank($atts->{'use'}, $_->{rank});
            $self->set_test_attr($_, 'std_solution_id', $self->get_named_object($use)->{id});
        }
    }
}


1;
