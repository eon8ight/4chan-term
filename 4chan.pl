#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use File::Fetch;
use HTML::Entities;
use JSON;
use REST::Client;
use Term::ANSIColor qw( :constants :pushpop );
use Term::ProgressBar;

$Term::ANSIColor::AUTOLOCAL = 1;

binmode( STDOUT, ':utf8' );

my $REST_CLIENT = REST::Client->new();
my $PIPE_LESS   = '| less -R';

my %sanitize_chars = (
    '<br>' => "\n",
);

sub sanitize($)
{
    my ( $str ) = @_;

    my $sanitized = $str;
       $sanitized = decode_entities( $sanitized );

    foreach my $orig ( keys %sanitize_chars )
    {
        my $repl   =  $sanitize_chars{$orig};
        $sanitized =~ s/$orig/$repl/g;
    }

    my $retval = '';

    foreach my $line ( split( /\n/, $sanitized ) )
    {
        if( $line =~ m/\<a href=".+" class=".+"\>/ )
        {
            $line =~ s/\<a href=".+" class=".+"\>(.+)\<\/a\>/$1/;
        }

        if( $line =~ m/\<span class="quote"\>/ )
        {
            $line    =~ s/\<span class="quote"\>(.+)\<\/span\>/$1/;
            $retval .=  BRIGHT_GREEN $line;
        }
        else
        {
            $retval .= $line;
        }

        $retval .= "\n";
    }

    return $retval;
}

sub thread_image_dl($$;@)
{
    my ( $board, $thread_op, @save_location ) = @_;
    
    if( !$board || !$thread_op )
    {
        print "Usage: get images <board> <thread OP> [<save location>]\n";
        return;
    }
    
    $board =~ s/\///g;

    my $save_location = "$thread_op";
       $save_location = glob join( ' ', @save_location ) if @save_location;
    
    $REST_CLIENT->GET( "http://a.4cdn.org/$board/thread/$thread_op.json" );
    my $json = $REST_CLIENT->responseContent();

    unless( $json )
    {
        print "Thread does not exist.\n";
        return;
    }

    my $thread      = decode_json( $json );
    my $thread_name = $thread->{posts}->[0]->{sub};

    if( length( $thread_name ) > 24 )
    {
        $thread_name = substr( $thread_name, 0, 21 );
        $thread_name .= '...';
    }

    my $progress = Term::ProgressBar->new( {
        name   => $thread_name,
        count  => scalar @{$thread->{posts}},
        remove => 1,
        ETA    => 'linear',
    } );

    $progress->minor( 0 );
    $progress->max_update_rate( 1 );

    my $counter = 0;

    foreach my $post ( @{$thread->{posts}} )
    {
        next unless $post->{tim};

        my $filename = $post->{tim}      . $post->{ext};
        my $realname = $post->{filename} . $post->{ext};

        next if -e "$save_location/$realname";

        my $ff  = File::Fetch->new( uri => "http://i.4cdn.org/$board/$filename" );
        my $uri = $ff->fetch( to => $save_location );

        my $rename_uri = $uri;
           $rename_uri =~ s/^(.+)\/(.+)$/$1\/$realname/;

        rename( $uri, $rename_uri );

        $counter++;
        $progress->update( $counter );
    }

    $progress->update( scalar @{$thread->{posts}} );
    print "No new images to pull.\n" if $counter == 0;
}

sub print_image($$;@)
{
    my ( $board, $filename, @opts ) = @_;

    my $opts_str = @opts ? join( ' ', @opts ) : '';

    my $ff         = File::Fetch->new( uri => "http://i.4cdn.org/$board/$filename" );
    my $uri        = $ff->fetch( to => '/tmp' );
    my $image_ansi = `img2txt $opts_str -f ansi $uri`;

    print "\n";
    print $image_ansi;
}

sub print_post($$)
{
    my ( $board, $post ) = @_;

    my $comment  = $post->{com};
    my $filename = defined $post->{tim} ? $post->{tim} . $post->{ext} : undef;

    print "======== $post->{no} ========\n";
    print_image( $board, $filename ) if $filename && lc $post->{ext} ne '.webm';
    print sanitize( "\n$comment" ) if $comment;
    print "\n";
}

sub view_thread($$)
{
    my ( $board, $thread_op ) = @_;
    
    if( !$board || !$thread_op )
    {
        print "Usage: view post <board> <post number>\n";
        return;
    }

    $board =~ s/\///g;

    $REST_CLIENT->GET( "http://a.4cdn.org/$board/thread/$thread_op.json" );
    my $json = $REST_CLIENT->responseContent();

    unless( $json )
    {
        print "Thread does not exist.\n";
        return;
    }

    my $thread = decode_json( $json );
    my $op     = $thread->{posts}->[0];

    my $thread_title  = "$board | Thread $op->{no}";
       $thread_title .= " - $op->{sub}" if $op->{sub};
    
    open( my $less, $PIPE_LESS );
    binmode( $less, ':utf8' );
    select $less;

    print "$thread_title\n\n";
    print_post( $board, $_ ) for ( @{$thread->{posts}} );

    select STDOUT;
    close $less;
}

sub list_boards()
{
    $REST_CLIENT->GET( "http://a.4cdn.org/boards.json" );

    my $json   = $REST_CLIENT->responseContent();
    my $boards = decode_json( $json );

    open( my $less, $PIPE_LESS );
    binmode( $less, ':utf8' );
    select $less;

    foreach my $board ( @{$boards->{boards}} )
    {
        my $board_abbr = $board->{board};
        my $board_name = $board->{title};

        print "/$board_abbr/ - $board_name\n";
    }

    select STDOUT;
    close $less;
}

sub print_thread_preview($$)
{
    my ( $board, $thread_op ) = @_;

    $REST_CLIENT->GET( "http://a.4cdn.org/$board/thread/$thread_op.json" );

    my $json   = $REST_CLIENT->responseContent();
    my $thread = decode_json( $json );

    my $op       = $thread->{posts}->[0];
    my $title    = $op->{sub};
    my $comment  = $op->{com};
    my $filename = defined $op->{tim} ? $op->{tim} . $op->{ext} : undef;

    print "$thread_op";
    print " - $title" if $title;
    print "\n";

    print_image( $board, $filename, ( '-W', '32' ) ) if $filename && lc $op->{ext} ne '.webm';

    print sanitize( "\n$comment" ) if $comment;
    print "\n\n";
}

sub list_threads($)
{
    my ( $board ) = @_;

    if( !$board )
    {
        print "Usage: list threads <board>\n";
        return;
    }

    $REST_CLIENT->GET( "http://a.4cdn.org/$board/threads.json" );
    my $json = $REST_CLIENT->responseContent();

    unless( $json )
    {
        print "Board does not exist.\n";
        return;
    }

    my $threads = decode_json( $json );

    open( my $less, $PIPE_LESS );
    binmode( $less, ':utf8' );
    select $less;

    foreach my $page ( @$threads )
    {
        print "Page $page->{page}\n";

        foreach my $thread ( @{$page->{threads}} )
        {
            print_thread_preview( $board, $thread->{no} );
        }
    }

    select STDOUT;
    close $less;
}

my $commands = {
    'pull' => {
        'images' => \&thread_image_dl,
    },
    'view' => {
        'thread' => \&view_thread,
    },
    'list' => {
        'boards'  => \&list_boards,
        'threads' => \&list_threads,
    },
};

# Program main

print "Imageboard for your terminal\n";
print "by \"Once Again I've Concocted Something Useless\" Labs\n\n";
print "Enter 'help' for a list of commands.\n";

while( 1 )
{
    print '> ';

    my $input  = <STDIN>;
    my @tokens = split( /\s+/, $input );
    
    my $cmd = shift @tokens;

    next unless $cmd;
    last if $cmd eq 'exit';

    my $subcmd = shift @tokens;
    my $opts   = $commands->{$cmd};
    
    if( $opts )
    {
        my $func = defined $subcmd ? $opts->{$subcmd} : undef;
        
        if( $func )
        {
            &$func( @tokens );
        }
        else
        {
            print "Valid $cmd commands are:\n";
            print "  $_\n" for ( keys %$opts );
        }
    }
    else
    {
        print "Valid commands are: \n";
        print "  $_\n" for ( keys %$commands );
        print "  exit\n";
    }
}

exit 0;
