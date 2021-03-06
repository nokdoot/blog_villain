#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use feature qw/ say /;

use lib "$ENV{BLOGVILLAIN_HOME}/lib";
use BlogVillain::Schema;

use AnyEvent::Loop;
use AnyEvent;
use AnyEvent::Filesys::Notify;
use POSIX qw ( strftime );
use Carp;

my $schema = BlogVillain::Schema->connect('BLOGVILLAIN_DATABASE');
my $notifier = AnyEvent::Filesys::Notify->new(
    dirs     => [ "$ENV{BLOGVILLAIN_HOME}\/public\/post\/" ],
    # Optional depending on underlying watcher
    interval => 2.0,             
    filter   => sub { 
        shift =~ m|$ENV{BLOGVILLAIN_HOME}/public/post/.*\.pod$|x 
    },
    cb       => sub {
        my (@events) = @_;
        open (my $log, '>>', "$ENV{BLOGVILLAIN_HOME}/log/watch-pod.log");
        for my $event ( @events ) {
            my $post = file_to_post($event);
            my $time = localtime;
            say $log "------------------------------";
            say $log $time;
            say $log $event->path;
            say $log $event->type;
            say $log "";
            _create($post) if $event->is_created;
            _update($post) if $event->is_modified;
            _delete($post) if $event->is_deleted;
        }
    },
    parse_events => 0,  # Improves efficiency on certain platforms
);

# enter an event loop, see AnyEvent documentation
AnyEvent::Loop::run;

sub file_to_post {
    my $event = shift;
    my $file  = $event->path;
    # ab/sol/ute/public/post/category/full/title.pod

    my $time  = strftime("%Y-%m-%dT%H:%M:%S", localtime);

    my $pod   = "";
    $pod      = readpod($file) if $event->is_modified;

    $file     =~ s/\.pod$//; # .pod is not needed anymore
    #remove absolute path
    $file     =~ s|$ENV{BLOGVILLAIN_HOME}/public/post/||;

    my $category = $1 if $file =~ m|(.*?)\/|;

    $file =~ s/$1\/{0,}//;
    my $fulltitle = $file;

    my $title = $2 if $fulltitle =~ m|(.*\/)*(.+)|;

    return {
        title     => $title,
        category  => $category,
        fulltitle => $fulltitle,
        pod       => $pod,
        time      => $time,
    };
}

sub _create {
    my $post = shift;
    $schema->resultset('Post')->create($post)
        or croak "Error of creating";
}

sub _delete {
    my $post = shift;
    $schema->resultset('Post')
        ->search({ fulltitle => $post->{fulltitle} })
        ->delete_all
        or croak "Error of deleting";
}

sub _update {
    my $post = shift;
    my $rs = $schema->resultset('Post')
        ->search({ fulltitle => $post->{fulltitle} });

    _create($post) if $rs->count eq 0;

    $rs->update_all({ pod => $post->{pod} })
        or croak "Error of _updating";
}

sub readpod {
	my $name = shift;
	local $/ = undef;
	open(my $file, '<:encoding(utf8)', $name) 
        or die "Could not open file '$name'";
	my $pod  = <$file>;
	close $file;
	$pod;
}
