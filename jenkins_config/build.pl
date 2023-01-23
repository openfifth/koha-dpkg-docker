#!/usr/bin/perl

use strict;
use warnings;

my $env_vars = {
    SYNC_REPO     => $ENV{SYNC_REPO} || '.',
    DEBS_OUT     => $ENV{DEBS_OUT} || './debs',
    LOCAL_USER_ID => qx{id -u},
    KDD_IMAGE     => $ENV{KDD_IMAGE} || 'master',
    KDD_BRANCH    => $ENV{KDD_BRANCH} || 'master',
};
while ( my ( $var, $value ) = each %$env_vars ) {
    $ENV{$var} = $value;
}

# Cleanup
run(q{rm -rf cover_db});
run(q{git clean -f});

my $GITLAB_RAW_URL = "https://gitlab.com/ptfs-europe/koha-debs-docker/raw/" . $ENV{KDD_BRANCH};

my $docker_compose_env = "$GITLAB_RAW_URL/env/defaults.env";
run(qq{wget -O .env $docker_compose_env}, { exit_on_error => 1 });

my $docker_compose_yml = "$GITLAB_RAW_URL/docker-compose.yml";
run(qq{wget -O docker-compose.yml $docker_compose_yml}, { exit_on_error => 1 });

docker_cleanup();

run(qq{mkdir -p \$DEBS_OUT});

my $cmd = 'docker-compose -f docker-compose.yml pull';
run($cmd, { exit_on_error => 1 });

# Run tests
$cmd = 'docker-compose -f docker-compose.yml -p koha up --abort-on-container-exit --no-color --force-recreate';
run($cmd, { exit_on_error => 1, use_pipe => 1 });

# Post cleanup
docker_cleanup();

run(qq{rm -f docker-compose.yml});
run(q{rm -rf .env});

sub run {
    my ( $cmd, $params ) = @_;
    my $exit_on_error = $params->{exit_on_error};
    my $use_pipe      = $params->{use_pipe};
    if ( $use_pipe ) {
        $cmd .= " 2>&1";
        my $fh;
        if ( $exit_on_error ) {
            open($fh, '-|', $cmd) or die "Failed to execute: $cmd ($!)";
        } else {
            open($fh, '-|', $cmd);
            if ($!) { warn "Failed to execute: $cmd ($!)"; return; }
        }
        while (my $line = <$fh>) { print $line }
    } else {
        if ( $exit_on_error ) {
            print qx{$cmd} . "\n" or die "Failed to execute $cmd";
        } else {
            print qx{$cmd} . "\n";
        }
    }
}

sub docker_cleanup {
    run(q{docker-compose -p koha down});
    run(qq{docker stop \$(docker ps -a -f "name=koha_" -q)});
    run(qq{docker rm \$(docker ps -a -f "name=koha_" -q)});
    run(q{docker volume prune -f});
    run(q{docker image  prune -f});
    run(q{docker system prune -a -f});
}
