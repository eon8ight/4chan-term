package TermChan::API;

use strict;
use warnings;

use JSON;
use Readonly;
use REST::Client;

use base 'Exporter';
our @EXPORT = qw( get_thread_obj get_catalog_obj get_boards_obj );

Readonly my $_REST_CLIENT => REST::Client->new();

sub _get($$)
{
    my ( $url, $errstr ) = @_;

    $_REST_CLIENT->GET( $url );
    my $json = $_REST_CLIENT->responseContent();

    unless( $json )
    {
        print "$errstr\n";
        return;
    }

    return decode_json( $json );
}

sub get_thread_obj($$)
{
    my ( $board, $thread_op ) = @_;

    return _get(
        "http://a.4cdn.org/$board/thread/$thread_op.json",
        'Thread does not exist.'
    );
}

sub get_catalog_obj($)
{
    my ( $board ) = @_;

    return _get(
        "http://a.4cdn.org/$board/catalog.json",
        'Board does not exist.'
    );
}

sub get_boards_obj()
{
    return _get(
        'http://a.4cdn.org/boards.json',
        'No boards to show - is your internet connection down?.'
    );
}

1;
