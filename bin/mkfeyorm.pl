#!/usr/bin/env perl
# ABSTRACT: App::mkfeyorm wrapper script. Make skeleton code with Fey::ORM.
# PODNAME: mkfeyorm.pl

use utf8;
use strict;
use warnings;
use autodie;
use Getopt::Long::Descriptive;
use App::mkfeyorm;

my ( $opt, $usage ) = describe_options(
    "%c %o ...",
    [ 'schema|s=s',         'schema module name'                        ],
    [ 'tables|t=s@',        'table module name list', { default => [] } ],
    [ 'namespace|n=s',      'base namespace'                            ],
    [ 'table_namespace=s',  'base table namespace'                      ],
    [ 'schema_namespace=s', 'base schema namespace'                     ],
    [ 'cache',              'turn on cache feature'                     ],
    [
        'output_path|o=s',
        'base directory (default: lib/)',
        { default => 'lib' },
    ],
    [],
    [ 'verbose|v', 'print extra stuff', { default => 0 } ],
    [ 'help|h',    'print usage message and exit'        ],
);

print($usage->text), exit                          if     $opt->help;
print("must specify schema\n", $usage->text), exit unless $opt->schema;
print("must specify tables\n", $usage->text), exit unless $opt->tables;

my $app = App::mkfeyorm->new(
    schema           => $opt->schema,
    tables           => $opt->tables,
    output_path      => $opt->output_path,
    namespace        => $opt->namespace        || q{},
    table_namespace  => $opt->table_namespace  || q{},
    schema_namespace => $opt->schema_namespace || q{},
    cache            => $opt->cache            || 0,
);

$app->process;

__END__

=head1 SYNOPSIS

    $ mkfeyorm.pl \
        --namespace MedicalCoding::Test \
        --table_namespace Model \
        --schema Schema \
        --table AE::Source \
        --table AE::Task \
        --table CM::Source \
        --table CM::Task \
        --table MC::User \
        --table MC::Role \
        --table MC::UserRole


=head1 DESCRIPTION

This is a L<App::mkfeyorm> wrapper script.
At least C<--schema> and C<--table> options are needed.


=head1 OPTIONS

    mkfeyorm.pl [-hnostv] [long options...] ...
        -s --schema             schema module name
        -t --tables             table module name list
        -n --namespace          base namespace
        --table_namespace       base table namespace
        --schema_namespace      base schema namespace
        -o --output_path        base directory (default: lib/)
    
        -v --verbose            print extra stuff
        -h --help               print usage message and exit


=head1 SEE ALSO

=over

=item L<Fey::ORM>

=item L<App::mkfeyorm>

=back
