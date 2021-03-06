package Catmandu::Fix::sum;

use Catmandu::Sane;
use List::Util ();
use Moo;
use Catmandu::Fix::Has;

has path => (fix_arg => 1);

with 'Catmandu::Fix::SimpleGetValue';

sub emit_value {
    my ($self, $var) = @_;

    "if (is_array_ref(${var})) {" .
        "${var} = List::Util::sum(\@{${var}}) // 0;" .
    "}";
}

=head1 NAME

Catmandu::Fix::sum - replace the value of an array field with the sum of it's elements

=head1 SYNOPSIS

   # e.g. numbers => [2, 3]
   sum(numbers)
   # numbers => 5

=head1 SEE ALSO

L<Catmandu::Fix>

=cut

1;

