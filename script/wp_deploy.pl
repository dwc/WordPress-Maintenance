#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Find ();
use File::ShareDir qw(dist_dir);
use File::Spec;
use File::Temp qw(tempdir);
use Getopt::Long;
use Template;
use WordPress::Config;
use WordPress::Directories;
use WordPress::Executables;


##
## Globals
##

our @DEFAULT_RSYNC_ARGS = qw(
    --archive
    --verbose
    --compress
    --delete-after
    --no-perms
    --no-group
    --chmod=ugo=rwX
);
our @DEFAULT_RSYNC_EXCLUDES = qw(
    /license.txt
    /readme.html
    /wp-config-sample.php
);


##
## Main script
##

main(@ARGV);
sub main {
    my $source_directory   = File::Spec->curdir;
    my $environment        = 'dev';
    my $template_directory = dist_dir('WordPress');
    my $checkout           = 0;
    die usage() unless GetOptions(
        'source|src|s=s'      => \$source_directory,
        'environment|env|e=s' => \$environment,
        'templates|t=s'       => \$template_directory,
        'checkout|C'          => \$checkout,
    );

    die "Directory ($template_directory) does not exist"
        unless -d $template_directory;

    my $www_directory = File::Spec->join($source_directory, 'www');
    die "Source ($source_directory) does not appear to be WordPress site checkout\n"
        unless -d $www_directory and -d File::Spec->join($www_directory, $WordPress::Directories::CONTENT);

    my $config = WordPress::Config->new($source_directory);
    my $environment_config = $config->for_environment($environment);
    exists $environment_config->{gatorlink_auth} or $environment_config->{gatorlink_auth} = 1;

    my $stage_directory = tempdir(CLEANUP => 1);
    stage($www_directory, $environment_config, $config->users, $template_directory, $stage_directory, $checkout);
    deploy($stage_directory, $environment_config);
}


##
## Subroutines
##

sub usage {
    return <<"END_OF_USAGE";
Usage: $0 [OPTION]...

Available options:
  -s, --source         The path to the site SVN checkout
  -e, --environment    The environment to deploy (dev, test, prod)
  -t, --templates      The path to the directory containing configuration file
                       templates
  -C, --checkout       Keep SVN checkout data when deploying
END_OF_USAGE
}

sub stage {
    my ($www_directory, $config, $users, $template_directory, $stage_directory, $checkout) = @_;

    stage_wordpress($www_directory, $stage_directory, $checkout);
    stage_configuration($config, $users, $template_directory, $stage_directory);

    if (my $shebang = $config->{shebang}) {
        my @executables = map { File::Spec->join($stage_directory, $_) } @WordPress::Executables::ALL;
        add_shebang($shebang, \@executables);
        make_executable(\@executables);
    }

    my $wp_content_directory = File::Spec->join($stage_directory, $WordPress::Directories::CONTENT);

    # Add plugin directories
    for (@WordPress::Directories::PLUGIN) {
        my $directory = File::Spec->join($wp_content_directory, $_);
        mkdir $directory;
    }

    # Add wp-cache symbolic link
    my $cwd = Cwd::getcwd();
    chdir $wp_content_directory;
    symlink
        File::Spec->join('plugins', 'wp-cache', 'wp-cache-phase1.php'),
        'advanced-cache.php';
    chdir $cwd;

    # Add robots.txt if requested
    if ($config->{exclude_robots}) {
        open my $fh, '>', File::Spec->join($stage_directory, 'robots.txt') or die $!;
        print $fh "User-agent: *\nDisallow: /\n";
        close $fh;
    }
}

sub stage_wordpress {
    my ($www_directory, $stage_directory, $checkout) = @_;

    my @excludes = @DEFAULT_RSYNC_EXCLUDES;
    unless ($checkout) {
        push @excludes, '.svn/';
    }

    my @args = @DEFAULT_RSYNC_ARGS;
    push @args, ('--exclude', $_) for @excludes;

    copy($www_directory, $stage_directory, \@args);
}

sub stage_configuration {
    my ($config, $users, $template_directory, $stage_directory) = @_;

    my $tt = Template->new(
        INCLUDE_PATH => $template_directory,
        ABSOLUTE     => 1,
    );

    my $stash = {
        users => $users,
        %{ $config },
    };

    my @files;
    File::Find::find(sub {
        return if -d $File::Find::name;
        return if $File::Find::dir =~ /\B\.svn\b/;
        return if $File::Find::dir =~ /\Bmint\b/
            and not -d File::Spec->join($stage_directory, $WordPress::Directories::MINT);

        my $relative = File::Spec->abs2rel($File::Find::name, $template_directory);
        my $final = File::Spec->join($stage_directory, $relative);
        $tt->process($File::Find::name, $stash, $final) or croak $tt->error . "\n";
    }, $template_directory);
}

sub add_shebang {
    my ($shebang, $executables) = @_;

    foreach my $executable (@$executables) {
        next unless -f $executable;

        my $fh;

        open $fh, '<', $executable or croak "Error opening $executable: $!";
        my $content = do { local $/; <$fh> };
        close $fh;

        open $fh, '>', $executable or die "Error opening $executable: $!";
        print $fh $shebang, "\n", $content;
        close $fh;
    }
}

sub make_executable {
    my ($executables) = @_;

    # suEXEC at OSG requires 0755
    chmod 0755, grep { -f } @$executables;
}

sub deploy {
    my ($stage_directory, $config) = @_;

    my $target = $config->{path};
    if (my $host = $config->{host} and my $user = $config->{user}) {
        $target = $user . '@' . $host . ':' . $target;
    }

    copy($stage_directory, $target, \@DEFAULT_RSYNC_ARGS);
    set_ownership($config->{path}, $config->{user}, $config->{group}, $config->{host});

    if (my $server_group = $config->{server_group}) {
        for (@WordPress::Directories::PLUGIN) {
            my $directory = File::Spec->join($config->{path}, $WordPress::Directories::CONTENT, $_);
            set_ownership($directory, $config->{user}, $server_group, $config->{host});
        }
    }
}

sub set_ownership {
    my ($path, $user, $group, $host) = @_;

    return unless $group;

    my @cmd = ('chgrp', '-R', $group);
    if ($user) {
        @cmd = ('chown', '-R', "$user:$group");
    }

    push @cmd, $path;

    if ($host) {
        unshift @cmd, 'ssh', $host, '-l', $user;
    }

    system(@cmd);
}

sub copy {
    my ($sources, $destination, $args) = @_;

    my $ref = ref $sources;
    $sources = [ $sources ] unless $ref and $ref eq 'ARRAY';

    my @args = (
        @$args,
        map { "$_/" } @$sources, $destination,
    );

    system('rsync', @args);
}