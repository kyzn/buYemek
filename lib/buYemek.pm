package buYemek;

use strict;
use warnings;

use DateTime;

=head1 NAME

buYemek - Main Library for buYemek

=head1 DESCRIPTION

Parse PDF dining hall menus monthly & auto-tweet daily

=head1 AUTHOR

Kivanc Yazan C<< <kyzn at cpan.org> >>

=head1 METHODS

=head2 new

Returns a new buYemek object.

=cut

sub new{
  return bless {
    url     => 'http://www.boun.edu.tr/Assets/Documents/Content/Public/kampus_hayati/yemek_listesi.pdf',
    month   =>  DateTime->now->month,
  }, shift;
}

1;
__END__
