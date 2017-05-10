package TermChan::API;

use strict;
use warnings;

use JSON;
use REST::Client;

use base 'Exporter';
our @EXPORT = qw( get_thread_obj get_catalog_obj get_boards_obj );

my $REST_CLIENT = REST::Client->new();

sub get_thread_obj($$)
{
    my ( $board, $thread_op ) = @_;
    
    $REST_CLIENT->GET( "http://a.4cdn.org/$board/thread/$thread_op.json" );
    my $json = $REST_CLIENT->responseContent();

    unless( $json )
    {
        print "Thread does not exist.\n";
        return;
    }

    my $thread = decode_json( $json );
    return $thread;
}

sub get_catalog_obj($)
{
    my ( $board ) = @_;

    $REST_CLIENT->GET( "http://a.4cdn.org/$board/catalog.json" );
    my $json = $REST_CLIENT->responseContent();

    unless( $json )
    {
        print "Board does not exist.\n";
        return;
    }

    my $threads = decode_json( $json );
    return $threads;
}

sub get_boards_obj()
{
    $REST_CLIENT->GET( "http://a.4cdn.org/boards.json" );

    my $json   = $REST_CLIENT->responseContent();
    my $boards = decode_json( $json );

    return $boards;
}

1;
