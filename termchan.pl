#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Data::UUID;
use File::Fetch;
use File::Util;
use Getopt::Long;
use Term::ProgressBar;
use Term::ReadLine;

use TermChan::API;
use TermChan::Post;

# Get opts first
my $no_images = 0;

GetOptions('no-images' => \$no_images);

sub print_less($)
{
    my ( $text ) = @_;

    File::Util->new()->make_dir( $TMP_DIR ) unless -e $TMP_DIR;

    my $uuid = Data::UUID->new()->create_str();
    my $text_tmp = "$TMP_DIR/$uuid.txt";

    open( my $text_fh, '>', $text_tmp );
    print {$text_fh} $text;
    close( $text_fh );

    system( 'less', '-R', $text_tmp );

    unlink $text_tmp;
}

sub get_timer($$)
{
    my ( $label, $max ) = @_;

    my $timer = Term::ProgressBar->new( {
        name   => $label,
        count  => $max,
        remove => 1,
        ETA    => 'linear',
    } );

    $timer->minor( 0 );
    $timer->max_update_rate( 1 );

    return $timer;
}

sub pull_images($$;@)
{
    my ( $board, $thread_op, @save_location ) = @_;

    if( !$board || !$thread_op )
    {
        print "Usage: get images <board> <thread OP> [<save location>]\n";
        return;
    }

    $board =~ s/\///g;

    my $thread      = get_thread_obj( $board, $thread_op );
    my $thread_name = defined $thread->{posts}->[0]->{sub}
                    ? $thread->{posts}->[0]->{sub}
                    : "$thread_op";

    my $save_location = @save_location
                      ? glob join( ' ', @save_location )
                      : '.';

    $save_location .= "/$thread_name";

    if( length( $thread_name ) > 24 )
    {
        $thread_name = substr( $thread_name, 0, 21 );
        $thread_name .= '...';
    }

    my $timer_max = scalar @{$thread->{posts}};
    my $progress  = get_timer( $thread_name, $timer_max );
    my $counter   = 0;

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

        $progress->update( $counter++ );
    }

    $progress->update( $timer_max );
    print "No new images to pull.\n" if $counter == 0;
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

    my $thread = get_thread_obj( $board, $thread_op );
    my $op     = $thread->{posts}->[0];

    my $thread_title  = "/$board/ - Thread $op->{no}";
       $thread_title .= " - $op->{sub}" if $op->{sub};

    my $reply_count = scalar @{$thread->{posts}};

    my $thread_str  = "\n";
       $thread_str .= " $thread_title\n";
       $thread_str .= " Created: $op->{now}\n";
       $thread_str .= " $reply_count Posts\n\n";

    my $progress = get_timer( "Loading posts from /$board/$op->{no}", $reply_count );
    my $counter  = 0;

    foreach my $post_obj ( @{$thread->{posts}} )
    {
        $thread_str .= get_post_str( $board, $post_obj, $no_images );
        $progress->update( $counter++ );
    }

    $progress->update( $reply_count );
    print_less( $thread_str );
}

sub list_boards()
{
    my $boards         = get_boards_obj();
    my $board_list_str = '';

    foreach my $board ( @{$boards->{boards}} )
    {
        my $board_abbr = $board->{board};
        my $board_name = $board->{title};

        $board_list_str .= "/$board_abbr/ - $board_name\n";
    }

    print_less( $board_list_str );
}

sub list_threads($;$)
{
    my ( $board, $req_page ) = @_;

    if( !$board )
    {
        print "Usage: list threads <board> [<page>]\n";
        return;
    }

    $board      =~ s/\///g;
    my $threads =  get_catalog_obj( $board );

    if( defined $req_page && $req_page > scalar @$threads )
    {
        print "Page out of range.\n";
        return;
    }

    my $thread_list_str = '';

    my $num_threads  = scalar @{$threads->[0]->{threads}};
       $num_threads *= scalar @$threads if !defined $req_page;

    my $progress = get_timer( "Loading threads on /$board/", $num_threads );
    my $counter  = 0;

    foreach my $page ( @$threads )
    {
        next if defined $req_page && $page->{page} != $req_page;

        $thread_list_str .= "\n";
        $thread_list_str .= " /$board/ - Page $page->{page}\n\n";

        foreach my $post_obj ( @{$page->{threads}} )
        {
            $thread_list_str .= get_op_post_str( $board, $post_obj, $no_images );
            $progress->update( $counter++ );
        }
    }

    $progress->update( $num_threads );
    print_less( $thread_list_str );
}

sub search_catalog($@)
{
    my ( $board, @keywords ) = @_;

    if( !$board || !@keywords )
    {
        print( "Usage: search catalog <board> <keyword>[, <keyword>, ...]\n" );
        return;
    }

    $board      =~ s/\///g;
    my $threads = get_catalog_obj( $board );

    my $catalog_str = '';

    my $num_threads = scalar( @{$threads->[0]->{threads}} ) * scalar( @$threads );
    my $progress    = get_timer( "Searching threads on /$board/", $num_threads );
    my $counter     = 0;

    foreach my $page ( @$threads )
    {
        foreach my $op ( @{$page->{threads}} )
        {
            my $com = defined $op->{com} ? lc $op->{com} : '';
            my $sub = defined $op->{sub} ? lc $op->{sub} : '';

            foreach my $keyword ( @keywords )
            {
                $keyword = lc $keyword;

                if( $com =~ m/$keyword/ || $sub =~ m/$keyword/ )
                {
                    $catalog_str .= get_op_post_str( $board, $op, $no_images );
                    last;
                }
            }

            $progress->update( $counter++ );
        }
    }

    $progress->update( $num_threads );
    print_less( $catalog_str );
}

my $COMMANDS = {
    'pull' => {
        'images' => \&pull_images,
    },
    'view' => {
        'thread' => \&view_thread,
    },
    'list' => {
        'boards'  => \&list_boards,
        'threads' => \&list_threads,
    },
    'search' => {
        'catalog' => \&search_catalog,
    },
};

# Program main

binmode( STDOUT, ':utf8' );

if( !$no_images )
{
    die "img2txt command not found - please install caca-utils.\n" unless `which img2txt`;
}

print "Imageboard for your terminal";
print ' (minus images)' if $no_images;
print "\n";
print "by \"Once Again I've Concocted Something Useless\" Labs\n\n";
print "Enter 'help' for a list of commands.\n";

my $terminal = Term::ReadLine->new( 'TermChan' );
   $terminal->ornaments( 0 );

while( defined( my $input = $terminal->readline( '> ' ) ) )
{
    my @tokens = split( /\s+/, $input );

    my $cmd = shift @tokens;

    next unless $cmd;
    last if $cmd eq 'exit';

    my $subcmd = shift @tokens;
    my $opts   = $COMMANDS->{$cmd};

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
            print "  $_\n" for keys %$opts;
        }
    }
    else
    {
        print "Valid commands are: \n";
        print "  $_\n" for keys %$COMMANDS;
        print "  exit\n";
    }
}

exit 0;
