package TermChan::IO;

use strict;
use warnings;

use HTML::Entities;
use Readonly;
use Term::ANSIColor qw( :constants :pushpop );
use Text::ANSITable;

use base 'Exporter';
our @EXPORT = qw( sanitize get_table_printer print_less );

Readonly my %_SANITIZE_CHARS => (
    '<br>'  => "\n",
    '<wbr>' => '',
);

sub sanitize($)
{
    my ( $str ) = @_;

    my $sanitized = $str;
       $sanitized = decode_entities( $sanitized );

    foreach my $orig ( keys %_SANITIZE_CHARS )
    {
        my $repl   =  $_SANITIZE_CHARS{$orig};
        $sanitized =~ s/$orig/$repl/g;
    }

    my $retval = '';

    foreach my $line ( split( /\n/, $sanitized ) )
    {
        if( $line =~ m/\<a href=".+" class=".+"\>/ )
        {
            $line =~ s/\<a href=".+" class=".+"\>(.+)\<\/a\>/$1/;
        }

        if( $line =~ m/\<span class=".+"\>/ )
        {
            $line    =~ s/\<span class=".+"\>(.+)\<\/span\>/$1/;
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

sub get_table_printer()
{
    my $table = Text::ANSITable->new();
       $table->use_utf8( 1 );
       $table->border_style( 'Default::bold' );
       $table->color_theme( 'Default::no_color' );

    return $table;
}

sub print_less($)
{
    my ( $text ) = @_;

    open( my $less, '| less -R' );
    binmode( $less, ':utf8' );
    select $less;

    print $text;

    select STDOUT;
    close $less;
}

1;
