package App::mkfeyorm;
# ABSTRACT: Make skeleton code with Fey::ORM

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use namespace::autoclean;
use autodie;

use Template;
use File::Basename;
use File::Spec::Functions;

( my $TEMPLATE_DIR = $INC{'App/mkfeyorm.pm'} ) =~ s/\.pm$//;
my $SCHEMA_TEMPLATE = 'schema.tt';
my $TABLE_TEMPLATE  = 'table.tt';

has 'schema' => (
    is       => 'ro',
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
    is       => 'ro',
    isa      => 'TableRef',
    required => 1,
    coerce   => 1,
);

has '_db_tables' => (
    is       => 'ro',
    isa      => 'ArrayRef',
);

has 'output_path' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'lib',
);

has 'namespace' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'table_namespace' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'schema_namespace' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'template_path' => (
    is      => 'ro',
    isa     => 'Str',
    default => $TEMPLATE_DIR,
);

has 'schema_template' => (
    is      => 'ro',
    isa     => 'Str',
    default => $SCHEMA_TEMPLATE,
);

has 'table_template' => (
    is      => 'ro',
    isa     => 'Str',
    default => $TABLE_TEMPLATE,
);

has 'cache' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has '_template' => (
    is         => 'ro',
    isa        => 'Template',
    lazy_build => 1,
);

sub _build__template {
    my $self = shift;

    my $tt = Template->new({
        INCLUDE_PATH     => $self->template_path,
        OUTPUT_PATH      => $self->output_path,
        DEFAULT_ENCODING => 'utf-8',
    }) || die "$Template::ERROR\n";

    return $tt;
}

sub process {
    my $self = shift;

    $self->_process_schema;
    $self->_process_table($_, $self->tables->{$_}) for keys %{ $self->tables };
}

sub _process_schema {
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
        $self->schema_template,
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
        $self->table_template,
        $vars,
        $self->_gen_module_path($table),
    ) or die $self->_template->error, "\n";
}

sub _gen_module_path {
    my ( $self, $module ) = @_;

    return catfile( split(/::/, $module) ) . '.pm';
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
__END__

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


=attr tables

Table module name list (required)


=attr output_path

Output path for generated modules


=attr namespace

Namespace for schema and table module


=attr table_namespace

Namespace for table module


=attr schema_namespace

Namespace for schema module


=attr template_path

Template path. Default is the module installed directory.
If you want to use your own template file then use this attribute.


=attr schema_template

Schema template file. Default is C<schema.tt>.
If you want to use your own template file then use this attribute.


=attr table_template

Table template file. Default is C<table.tt>.
If you want to use your own template file then use this attribute.


=attr cache

Use cache feature or not. Default is false.
It uses L<Storable> to save and load cache file.


=method process

Make the skeleton perl module.


=head1 SEE ALSO

L<Fey::ORM>
