package Path::AttrRouter::DispatchType::Chained;
use Any::Moose;

use Carp;
use File::Spec::Unix;

use Path::AttrRouter::ActionChain;

has name => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Chained',
);

has chain_from => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has endpoints => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has actions => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

no Any::Moose;

sub match {
    my ($self, $path, $args, $captures) = @_;
    return if @$args;

    my @parts = split '/', $path;

    my ($chain, $action_captures, $parts) = $self->recurse_match('/', @parts);
    return unless $chain;

    @$args = @$parts;
    @$captures = @$action_captures;

    return Path::AttrRouter::ActionChain->from_chain($chain);
}

sub recurse_match {
    my ($self, $parent, @pathparts) = @_;

    my @chains = @{ $self->chain_from->{ $parent } || [] }
        or return;

    for my $action (@chains) {
        my @parts = @pathparts;

        my $pathpart = $action->attributes->{PathPart}[0];
        if (length $pathpart) {
            my @p = split '/', $pathpart;
            next if @p > @parts;

            my @stripped = splice @parts, 0, scalar @p;
            next unless $pathpart eq join '/', @stripped;
        }

        if (defined $action->attributes->{CaptureArgs}[0]) {
            my $capture_args = $action->attributes->{CaptureArgs}[0];
            next if @parts < $capture_args;

            my @captures = splice @parts, 0, $capture_args;
            my ($actions, $captures, $action_parts)
                = $self->recurse_match('/'.$action->reverse, @parts);
            next unless $actions;

            return ([ $action, @$actions ], [@captures, @$captures], $action_parts);
        }
        else {
            next unless $action->match_args(\@parts);
            return ([ $action ], [], \@parts);
        }
    }
}

sub register {
    my ($self, $action) = @_;

    my @chained = @{ $action->attributes->{Chained} || [] }
        or return;

    my $parent = $chained[0];
    if ($parent) {
        unless ($parent =~ m!^/!) {
            $parent = File::Spec::Unix->rel2abs($parent, '/' . $action->namespace);
        }
    }
    else {
        $parent = '/';
    }
    $action->attributes->{Chained} = [$parent];

    my $children = $self->chain_from->{ $parent } ||= [];
    my @pathpart = @{ $action->attributes->{PathPart} || [] };

    my $part = defined $pathpart[0] ? $pathpart[0] : $action->name;
    $action->attributes->{PathPart} = [$part];

    my $num_parts = sub {
        my $action = $_[0];
        my @parts = split '/', $action->attributes->{PathPart};
        my $num   = scalar @parts;
        if (defined $action->attributes->{CaptureArgs}[0]) {
            $num += $action->attributes->{CaptureArgs}[0];
        }
        else {
            $num += $action->num_args;
        }
    };

    $self->actions->{ '/' . $action->reverse } = $action;
    push @{ $self->endpoints }, $action unless $action->attributes->{CaptureArgs};

    @$children = sort { $num_parts->($b) <=> $num_parts->($a) } @$children, $action;
}

sub used {
    my ($self) = @_;
    scalar @{ $self->endpoints };
}

sub list {
    my ($self) = @_;
    return unless $self->used;

    my @rows = [[ 1 => 'Path Spec'], [ 1 => 'Private' ]];
    my @unattached;

    for my $endpoint (sort { $a->reverse cmp $b->reverse } @{ $self->endpoints }) {
        my @parts = defined $endpoint->num_args
                    ? ( ('*') x $endpoint->num_args )
                    : ('...');
        my @parents;

        my $cur = $endpoint;
        my $parent;
        while ($cur) {
            if (my $cap = $cur->attributes->{CaptureArgs}) {
                unshift @parts, (('*') x $cap->[0]) if $cap->[0];
            }
            if (my $pp = $cur->attributes->{PathPart}) {
                unshift @parts, $pp->[0]
                    if defined $pp->[0] and length $pp->[0];
            }
            $parent = $cur->attributes->{Chained}[0];
            $cur = $self->actions->{ $parent };

            unshift @parents, $cur if $cur;
        }

        if ($parent ne '/') {
            push @unattached,
                [ '/' . ($parents[0] || $endpoint)->reverse, $parent ];
            next;
        }

        my @r;
        for my $parent (@parents) {
            my $name = $parent->reverse eq $parents[0]->reverse
                       ? '/' . $parent->reverse
                       : '-> ' . $parent->reverse;

            if (my $cap = $parent->attributes->{CaptureArgs}) {
                $name .= ' (' . $cap->[0] . ')';
            }

            push @r, [ '', $name ];
        }
        push @r, [ '', (@r ? '=> ' : '') . '/' . $endpoint->reverse ];
        $r[0][0] = join('/', '', @parts) || '/';

        push @rows, @r;
    }

    if (@unattached) {
        push @rows, undef;
        push @rows, ['Private', 'Missing parent'];
        push @rows, undef;

        push @rows, @unattached;
    }

    \@rows;
}

__PACKAGE__->meta->make_immutable;
