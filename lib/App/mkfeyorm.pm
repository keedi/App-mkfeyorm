package App::mkfeyorm;
# ABSTRACT: Make skeleton code with Fey::ORM

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use autodie;

use Data::Section -setup;
use File::Basename;
use File::Spec::Functions;
use Template;

has 'schema' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

subtype 'TableRef',
    as 'HashRef';

sub _db_table_name {
    my $table = shift;

    $table =~ s/([A-Z]+)::/"_\L$1_"/ge;
    $table =~ s/([A-Z]+)([A-Z])/"_\L$1_$2"/ge;
    $table =~ s/([A-Z])/"_\L$1"/ge;
    $table =~ s/::/_/g;
    $table =~ s/_+/_/g;
    $table =~ s/^_//;

    return $table;
}

coerce 'TableRef',
    from 'ArrayRef',
    via {
        my %result = map { $_ => _db_table_name($_) } @$_;

        \%result;
    };

has 'tables' => (
    is       => 'rw',
    isa      => 'TableRef',
    required => 1,
    coerce   => 1,
);

has '_db_tables' => (
    is       => 'rw',
    isa      => 'ArrayRef',
);

has 'output_path' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'lib',
);

after 'set_output_path' => sub {
    my ( $self, $path ) = @_;

    my $tt = Template->new({
        OUTPUT_PATH      => $self->output_path,
        DEFAULT_ENCODING => 'utf-8',
    }) || die "$Template::ERROR\n";

    $self->_set_template($tt);
};

has 'namespace' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'table_namespace' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'schema_namespace' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'schema_template' => (
    is      => 'rw',
    isa     => 'Str',
    default => ${ __PACKAGE__->section_data('schema.tt') },
);

has 'table_template' => (
    is      => 'rw',
    isa     => 'Str',
    default => ${ __PACKAGE__->section_data('table.tt') },
);

has 'cache' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has '_template' => (
    is         => 'rw',
    isa        => 'Template',
    lazy_build => 1,
);

sub _build__template {
    my $self = shift;

    my $tt = Template->new({
        OUTPUT_PATH      => $self->output_path,
        DEFAULT_ENCODING => 'utf-8',
    }) || die "$Template::ERROR\n";

    return $tt;
}

sub process {
    my $self = shift;

    $self->process_schema;
    $self->_process_table($_, $self->tables->{$_}) for keys %{ $self->tables };
}

sub process_table {
    my ( $self, @tables ) = @_;

    if (@tables) {
        $self->_process_table($_, $self->tables->{$_}) for @tables;
    }
    else {
        $self->_process_table($_, $self->tables->{$_}) for keys %{ $self->tables };
    }
}

sub process_schema {
    my $self = shift;

    my $schema = join(
        '::',
        grep { $_ } (
            $self->namespace,
            $self->schema_namespace,
            $self->schema,
        )
    );

    my @tables = map {
        join(
            '::',
            grep { $_ } ( $self->namespace, $self->table_namespace, $_ )
        );
    } sort keys %{$self->tables};

    my $vars = {
        SCHEMA => $schema,
        TABLES => \@tables,
        CACHE  => $self->cache,
    };

    $self->_template->process(
        \$self->schema_template,
        $vars,
        $self->_gen_module_path($schema),
    ) or die $self->_template->error, "\n";
}

sub _process_table {
    my ( $self, $orig_table, $db_table ) = @_;

    $db_table = _db_table_name($orig_table) unless $db_table;

    my $schema = join(
        '::',
        grep { $_ } (
            $self->namespace,
            $self->schema_namespace,
            $self->schema
        )
    );

    my $table = join(
        '::',
        grep { $_ } (
            $self->namespace,
            $self->table_namespace,
            $orig_table,
        )
    );

    my $vars = {
        SCHEMA   => $schema,
        TABLE    => $table,
        CACHE    => $self->cache,
        DB_TABLE => $db_table,
    };

    $self->_template->process(
        \$self->table_template,
        $vars,
        $self->_gen_module_path($table),
    ) or die $self->_template->error, "\n";
}

sub _gen_module_path {
    my ( $self, $module ) = @_;

    return catfile( split(/::/, $module) ) . '.pm';
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SYNOPSIS

    use App::mkfeyorm;
    
    my $app = App::mkfeyorm->new(
        output_path      => 'somewhere/lib',
        schema           => 'Schema',
        tables           => [qw(
            MC::User
            MC::Role
            MC::UserRole
            AE::Source
            AE::Task
            CM::Source
            CM::Task
        )],
        namespace        => 'MedicalCoding',
        table_namespace  => 'Model',
    );
    
    $app->process;


=head1 DESCRIPTION

This module generates L<Fey::ORM> based module on the fly.
At least C<schema> and C<tables> attributes are needed.


=attr schema

Schema module name (required)

    my $schema_module_name = $self->schema;
    $self->set_schema($schema_module_name);


=attr tables

Table module name list (required)

    my $table_module_names_ref = $self->tables;
    $self->set_tables(\@table_module_names);
    $self->set_tables(\%table_module_names);


=attr output_path

Output path for generated modules.
Default output directory is C<lib>.

    my $output_path = $self->output_path;
    $self->set_output_path($output_path);


=attr namespace

Namespace for schema and table module


=attr table_namespace

Namespace for table module


=attr schema_namespace

Namespace for schema module


=attr schema_template

Schema template string.
If you want to use your own template file then use this attribute.


=attr table_template

Table template string.
If you want to use your own template file then use this attribute.


=attr cache

Use cache feature or not. Default is false.
It uses L<Storable> to save and load cache file.


=method process

Generate the schema module & table module

    my $app = App::mkfeyorm->new(
        schema          => 'Schema',
        tables          => {
            User     => 'user',
            Role     => 'role',
            UserRole => 'user_role',
        },
        namespace       => 'Web::Blog',
        table_namespace => 'Model',
    );
    $app->process;

=method process_schema

Generate the schema module.

    $app->process_schema;

=method process_table

Generate the table module.

    $app->process_table;                    # generates all tables
    $app->process_table( qw/ User Role / ); # generates User and Role tables


=head1 SEE ALSO

L<Fey::ORM>

=cut

__DATA__

__[ schema.tt ]__
package [% SCHEMA %];

use Fey::DBIManager::Source;
use Fey::Loader;
use Fey::ORM::Schema;
[% FOREACH TABLE = TABLES -%]
use [% TABLE %];
[% END -%]
[% IF CACHE -%]
use Storable;
use File::Basename;
use File::Path qw(make_path);
[% END -%]

sub load {
    my ( $class, %params ) = @_;

    return unless $class;
    return if     $class->Schema;

    _load_schema(%params) or die "cannot load schema\n";
    _load_tables(qw/
[% FOREACH TABLE = TABLES -%]
        [% TABLE %]
[% END -%]
    /) or die "cannot load tables\n";
}

sub _load_schema {
    my %params = @_;

    my %source_params = map {
        defined $params{$_} ? ( $_ => $params{$_} ) : ();
    } qw(
        name
        dbh
        dsn
        username
        password
        attributes
        post_connect
        auto_refresh
        ping_interval
    );

    my $source = Fey::DBIManager::Source->new( %source_params );
[% IF CACHE -%]
    my $schema;
    if ($params{cache_file} && -f $params{cache_file}) {
        $schema = retrieve($params{cache_file});
    }
    else {
        $schema = Fey::Loader->new( dbh => $source->dbh )->make_schema;
    }
[% ELSE -%]
    my $schema = Fey::Loader->new( dbh => $source->dbh )->make_schema;
[% END -%]
    return if ref($schema) ne 'Fey::Schema';

[% IF CACHE -%]
    my $updated;
[% END -%]
    if ($params{fk_relations}) {
[% IF CACHE -%]
        ++$updated;
[% END -%]
        for my $relation ( @{ $params{fk_relations} } ) {
            my $source_table  = $relation->{source_table};
            my $source_column = $relation->{source_column};
            my $target_table  = $relation->{target_table};
            my $target_column = $relation->{target_column};

            my $fk = Fey::FK->new(
                source_columns => $schema->table($source_table)->column($source_column),
                target_columns => $schema->table($target_table)->column($target_column),
            );
            $schema->add_foreign_key($fk);
        }
    }

    #
    # Add foreign key if it is needed or remove it
    #
    #my $fk;
    #
    #$fk = Fey::FK->new(
    #    source_columns => $schema->table('src_table')->column('col_id'),
    #    target_columns => $schema->table('dest_table')->column('col_id'),
    #);
    #$schema->add_foreign_key($fk);

[% IF CACHE -%]
    if ($params{cache_file}) {
        if (!-e $params{cache_file} || $updated) {
            my $dirname = dirname($params{cache_file});
            make_path($dirname) unless -e $dirname;
            store($schema, $params{cache_file});
        }
    }

[% END -%]
    has_schema $schema;

    __PACKAGE__->DBIManager->add_source($source);

    return 1;
}

sub _load_tables {
    my @tables = @_;

    $_->load for @tables;

    return 1;
}

1;
__[ table.tt ]__
package [% TABLE %];
use Fey::ORM::Table;
use [% SCHEMA %];

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use namespace::autoclean;

sub load {
    my $class = shift;

    return unless $class;
    return if     $class->Table;

    my $schema = [% SCHEMA %]->Schema;
    my $table  = $schema->table('[% DB_TABLE %]');

    has_table( $table );

    #
    # Add another relationships like has_one, has_many or etc.
    #
    #has_many items => ( table => $schema->table('item') );
}

1;
