package TermChan::Post;

use strict;
use warnings;

use File::Fetch;

use TermChan::IO;

use base 'Exporter';
our @EXPORT = qw( get_image_str get_post_str get_op_post_str );

sub get_image_str($$;@)
{
    my ( $board, $filename, @opts ) = @_;

    my $opts_str = @opts ? join( ' ', @opts ) : '';

    my $ff         = File::Fetch->new( uri => "http://i.4cdn.org/$board/$filename" );
    my $uri        = $ff->fetch( to => '/tmp' );
    my $image_ansi = `img2txt $opts_str -f ansi $uri`;

    my $retval  = "\n";
       $retval .= $image_ansi;

    return $retval;
}

sub _get_post_str($$;$)
{
    my ( $board, $post, $is_op ) = @_;
    
    my $comment       = $post->{com};
    my $filename      = defined $post->{tim} ? $post->{tim} . $post->{ext}      : undef;
    my $orig_filename = $filename            ? $post->{filename} . $post->{ext} : undef;
    my $dims          = $filename            ? "$post->{tn_w} x $post->{tn_h}"  : undef;

    my $finfo_cell = $orig_filename
                   ? "File: $orig_filename ($post->{fsize} B, $dims)"
                   : 'No image';

    my $post_name = $post->{name};

    if( $is_op )
    {
        my $title  = defined $post->{sub} ? "$post->{sub} - " : '';
        $post_name = $title . $post_name;
    }

    my $table = get_table_printer();
       $table->columns( [ "$post_name",     $post->{now} ] );
       $table->add_row( [ "No.$post->{no}", $finfo_cell ] );

    my $retval = $table->draw();

    if( $filename && lc $post->{ext} ne '.webm' )
    {
        $retval .= get_image_str( $board, $filename, ( '-W', '32' ) )
    }
    else
    {
        $retval .= "\n(.webm ommitted)\n";
    }

    $retval .= sanitize( "\n$comment" ) if $comment;
    $retval .= "\n";

    return $retval;
}

sub get_post_str($$)
{
    my ( $board, $post_obj ) = @_;
    return _get_post_str( $board, $post_obj );
}

sub get_op_post_str($$)
{
    my ( $board, $op_post_obj ) = @_;
    return _get_post_str( $board, $op_post_obj, 1 );
}

1;
