#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';

use Data::Dumper;
use Test::More;
use BlogVillain::Schema;
use DateTime;
use Encode;

my $schema = BlogVillain::Schema->connect('BLOGVILLAIN_DATABASE');
my $datetime = DateTime->now;

my $post_row = $schema->resultset('Post')->create({
	title => 'pod/perl/Set/Scalar',
}) or die ;
 print $post_row->{_column_data}->{title}."\n";
#$post_ma->delete or die;

done_testing();
