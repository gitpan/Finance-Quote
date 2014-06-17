#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2001, Rob Sessink <rob_ses@users.sourceforge.net>
#    Copyright (C) 2005, Morten Cools <morten@cools.no>
#    Copyright (C) 2006, Dominique Corbex <domcox@sourceforge.net>
#    Copyright (C) 2008, Bernard Fuentes <bernard.fuentes@gmail.com>
#    Copyright (C) 2009, Erik Colson <eco@ecocode.net>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
#
# Changelog
#
# 2014-01-12  Arnaud Gardelein
#
#     *       changes on website
#
# 2009-04-12  Erik Colson
#
#     *       Major site change.
#
# 2008-11-09  Bernard Fuentes
#
#     *       changes on website
#
# 2006-12-26  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.4) changes on web site
#
# 2006-09-02  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.3) changes on web site
#
# 2006-06-28  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.2) changes on web site
#
# 2006-02-22  Dominique Corbex <domcox@sourceforge.net>
#
#     * (1.0) iniial release
#

require 5.005;

use strict;

package Finance::Quote::Bourso;

use vars qw( $Bourso_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder
    ;    # Boursorama doesn't put data in table elements anymore but uses <div>

our $VERSION = '1.35'; # VERSION

my $Bourso_URL = 'http://www.boursorama.com/recherche/index.phtml';

sub methods {
    return ( france => \&bourso,
             bourso => \&bourso,
             europe => \&bourso
    );
}
{
    my @labels =
        qw/name last date isodate p_change open high low close volume currency method exchange/;

    sub labels {
        return ( france => \@labels,
                 bourso => \@labels,
                 europe => \@labels
        );
    }
}

sub bourso_to_number {
    my $x = shift(@_);
    $x =~ s/\s//g;    # remove spaces etc in number
    return $x;
}

sub bourso {
    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, $style );
    my $ua = $quoter->user_agent();

    $url = $Bourso_URL;

    foreach my $stocks (@stocks) {
        my $queryUrl =
              $url
            . join( '', "?q=", $stocks )
            . "&search[type]=rapide&search[categorie]=STK&search[bourse]=country:33";
        $reply = $ua->request( GET $queryUrl);

        # print "URL=".$queryUrl."\n";

        if ( $reply->is_success ) {

            # print $reply->content;
            $info{ $stocks, "success" } = 1;

            my $tree = HTML::TreeBuilder->new_from_content( $reply->content );

            # retrieve SYMBOL
            my @symbolline = $tree->look_down( 'class', 'fv-isin ellipsis' );

            unless (@symbolline) {
                $info{ $stocks, "success" }  = 0;
                $info{ $stocks, "errormsg" } = "Stock name $stocks not found";
                next;
            }

            my $symbol = ( $symbolline[0]->content_list )[0];
            ($symbol) = ( $symbol =~ m/(\w+)/ );
            $info{ $stocks, "symbol" } = $symbol;

            # retrieve NAME
            my @nameline = $tree->look_down( 'class', 'fv-name' );

            unless (@nameline) {
                $info{ $stocks, "success" } = 0;
                $info{ $stocks, "errormsg" } =
                    "Stock name $stocks not retrievable";
                next;
            }

            my $name = $nameline[0]->as_text;
            $info{ $stocks, "name" } = $name;

            # set method
            $info{ $stocks, "method" } = "bourso";

            #holds table data
            my %tempinfo;

            # retrieve other data
            my $infoclass = ( $tree->look_down( 'class', 'fv-extras' ) )[0];
            unless ($infoclass) {
                my $opcvm =
                    ( $tree->look_down( 'class', 'opcvm-partners block' ) )[0];
                unless ($opcvm) {
                    $info{ $stocks, "success" } = 0;
                    $info{ $stocks, "errormsg" } =
                        "$stocks retrieval not supported.";
                    next;
                }

                # the stock is a delayed OPCVM

                my $infoelem =
                    ( $tree->look_down( 'id', 'quote-infos-page' ) )[0];
                $infoelem =
                    ( $infoelem->look_down( 'class', 'q-details span-1-2' ) )
                    [0];

                my @rows = $infoelem->look_down( '_tag', 'tr' );
                foreach my $i ( 0 .. $#rows ) {
                    my $row = $rows[$i];
                    unless ( $row->attr('class') ) {
                        next;
                    }

                    my @cells     = $row->look_down( '_tag', 'td' );
                    my $keytext   = ( $cells[0] )->as_text;
                    my $valuetext = ( $cells[2] )->as_text;

                    $tempinfo{$keytext} = $valuetext;
                }
            }
            else {
                # regular stock

                my $infoelem;
                my $quote_infos_page =
                    ( $tree->look_down( 'id', 'quote-infos-page' ) )[0];
                $infoelem = ( $quote_infos_page->look_down(
                                                   'class', 'q-details span-1-2'
                              )
                )[0];
                $infoelem = ( $quote_infos_page->look_down( 'class', 'bd' ) )[0]
                    if ( !defined $infoelem );    # needed for warrants

                my @rows = $infoelem->look_down( '_tag', 'tr' );
                foreach my $i ( 0 .. $#rows ) {
                    my $row   = $rows[$i];
                    my @cells = $row->look_down( '_tag', 'td' );
                    my $j     = 0;
                    if ( $cells[0]->attr('rowspan') ) {
                        $j = 1;
                    }
                    if ( $cells[0]->attr('colspan') ) {
                        next;
                    }

                    my $keytext   = ( $cells[$j] )->as_text;
                    my $valuetext = ( $cells[ $j + 1 ] )->as_text;

                    $tempinfo{$keytext} = $valuetext;
                }
            }

            foreach my $key ( keys %tempinfo ) {

                # print "$key -> $tempinfo{$key}\n";

            ASSIGN: for ($key) {

                    # OPCVM
                    /Valeur liquidative/ && do {
                        my ( $last, $currency ) =
                            ( $tempinfo{$key}
                            =~ m/(\d+(?:\s\d+)*(?:\.\d+)?)(?:\(c\))?(?:\s+(\w+))?/
                            );
                        $last = bourso_to_number($last);
                        $info{ $stocks, "last" }     = $last;
                        $info{ $stocks, "currency" } = $currency;
                    };
                    /Date/ && do {
                        $info{ $stocks, "date" } = $tempinfo{$key};
                        $quoter->store_date( \%info, $stocks,
                                     { eurodate => $info{ $stocks, "date" } } );
                    };
                    /Variation Veille/ && do {
                        $info{ $stocks, "p_change" } = $tempinfo{$key};
                    };

                    # REGULAR STOCK
                    /Cours/ && do {
                        my ( $last, $currency ) =
                            ( $tempinfo{$key}
                            =~ m/(\d+(?:\s\d+)*(?:\.\d+)?)(?:\(c\))?(?:\s+(\w+))?/
                            );
                        $last = bourso_to_number($last);
                        $info{ $stocks, "last" } = $last;
                        $info{ $stocks, "currency" } =
                            $currency || "EUR";    # defaults to EUR
                        my $exchange = $key;
                        $exchange =~ s/.*Cours\s*(\w.*\w)\s*/$1/
                            ;    # the exchange is in the $key here
                        $info{ $stocks, "exchange" } = $exchange;
                    };
                    /Variation/ && do {
                        $info{ $stocks, "p_change" } = $tempinfo{$key};
                    };
                    /Dernier .change/ && do {
                        my ( $day, $month, $year ) =
                            ( $tempinfo{$key} =~ m|(\d\d)/(\d\d)/(\d\d)| );
                        $year += 2000;
                        $info{ $stocks, "date" } = sprintf "%02d/%02d/%04d",
                            $day, $month, $year;
                        $quoter->store_date( \%info, $stocks,
                                     { eurodate => $info{ $stocks, "date" } } );
                    };
                    /Volume/ && do {
                        $info{ $stocks, "volume" } =
                            bourso_to_number( $tempinfo{$key} );
                    };
                    /Ouverture/ && do {
                        $info{ $stocks, "open" } =
                            bourso_to_number( $tempinfo{$key} );
                    };
                    /Haut/ && do {
                        $info{ $stocks, "high" } =
                            bourso_to_number( $tempinfo{$key} );
                    };
                    /Bas/ && do {
                        $info{ $stocks, "low" } =
                            bourso_to_number( $tempinfo{$key} );
                    };
                    /Cl.ture veille/ && do {
                        $info{ $stocks, "previous" } =
                            bourso_to_number( $tempinfo{$key} );
                    };
                    /Valorisation/ && do {
                        $info{ $stocks, "cap" } = $tempinfo{$key};
                        $info{ $stocks, "cap" } =~ s/[A-Z\s]//g
                            ; # remove spaces and 'M' (millions) and currency (when not EUR)
                        $info{ $stocks, "cap" }
                            =~ tr/,/./;    # point instead of comma
                        $info{ $stocks, "cap" }
                            *= 1000000;    # valorisation is in millions
                    };
                }
            }
            $tree->delete;
        }
        else {
            $info{ $stocks, "success" }  = 0;
            $info{ $stocks, "errormsg" } = "Error retreiving $stocks ";
        }
    }
    return wantarray() ? %info : \%info;
    return \%info;
}
1;

=head1 NAME

Finance::Quote::Bourso Obtain quotes from Boursorama.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("bourso","ml");  # Only query Bourso
    %info = Finance::Quote->fetch("france","af"); # Failover to other sources OK.

=head1 DESCRIPTION

This module fetches information from the "Paris Stock Exchange",
http://www.boursorama.com. All stocks are available.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicity by placing "bourso" in the argument
list to Finance::Quote->new().

This module provides both the "bourso" and "france" fetch methods.
Please use the "france" fetch method if you wish to have failover
with future sources for French stocks. Using the "bourso" method
will guarantee that your information only comes from the Paris Stock Exchange.

Information obtained by this module may be covered by www.boursorama.com
terms and conditions See http://www.boursorama.com/ for details.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::Bourso :
name, last, date, p_change, open, high, low, close, nav,
volume, currency, method, exchange, symbol.

=head1 SEE ALSO

Boursorama (french web site), http://www.boursorama.com

=cut
