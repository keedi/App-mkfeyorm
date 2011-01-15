package App::mkfeyorm;
# ABSTRACT: Make skeleton code with Fey::ORM

use Moose;
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

has 'tables' => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
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
    $self->_process_table($_) for @{ $self->tables };
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
    } @{$self->tables};

    my $vars = {
        SCHEMA    => $schema,
        TABLES    => \@tables,
    };

    $self->_template->process(
        $self->schema_template,
        $vars,
        $self->_gen_module_path($schema),
    ) or die $self->_template->error, "\n";
}

sub _process_table {
    my ( $self, $orig_table ) = @_;

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

    my $db_table = $orig_table;
    $db_table =~ s/([A-Z]+)::/"_\L$1_"/ge;
    $db_table =~ s/([A-Z]+)([A-Z])/"_\L$1_$2"/ge;
    $db_table =~ s/([A-Z])/"_\L$1"/ge;
    $db_table =~ s/::/_/g;
    $db_table =~ s/_+/_/g;
    $db_table =~ s/^_//;

    my $vars = {
        SCHEMA   => $schema,
        TABLE    => $table,
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
        schema           => 'Schema.pm',
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

This module generates Fey::ORM based module on the fly.
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

Schema template file. Default is 'schema.tt'
If you want to use your own template file then use this attribute.


=attr table_template

Table template file. Default is 'table.tt'
If you want to use your own template file then use this attribute.


=method process

Make the skeleton perl module.


=head1 SEE ALSO

L<Fey::ORM>
