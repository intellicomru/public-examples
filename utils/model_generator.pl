#!/usr/bin/perl

### для DBIx создаем модуль описывающий таблицу. на основе реальной таблицы
use warnings;
use strict;
use utf8;
my $libs = "../lib/";
use FindBin;
use lib "../lib/";
use Cwd;
use uni::perl qw/:dumper/;
use String::Util ':all';
use Date::Parse qw(strptime);
use File::Basename;
use File::Spec;
use File::Path qw(make_path);

my ($sql, $res);
my $force_build         = $ARGV[0];
my $project_name        = $ARGV[1];
my $table_schema        = $ARGV[2];
my $table_name          = $ARGV[3];
my $table_name_original = $ARGV[3];

if ($table_name =~ /es$/) {
    chop($table_name);
    chop($table_name);
} elsif ($table_name =~ /s$/ && !($table_name =~ /ss$/)) {
    chop($table_name);
}

my $model_path          = "$project_name/Schema/$table_schema/$table_name.pm";
my $model_dir           = dirname($model_path);

if (!$project_name || !$table_schema || !$table_name) {
    usage();
}

my $module = $project_name."::Schema";
print "Module for use: $module\n";
eval {
    (my $file = $module) =~ s|::|/|g;
    require $file . '.pm';
    $module->import();    
    1;
} or do {
   my $error = $@;
   die("Error load module => $module".dumper($error));
};


# connection to database
my $connect = undef;
# hash for database structure
my %database_structure = ();

sub usage {
    print " Инструкция: https://goo.gl/plZh79\n";
    print " Запускать так: ./model_generator.pl -noforce ИМЯ_ПРОЕКТА ИМЯ_СХЕМЫ ИМЯ_ТИБЛИЦЫ\n";
    print " если надо просто перегенерить модель, то запускать с ключем '--force', например так:\n";
    print " ./model_generator.pl --force Contragent Thesaurus Currency\n";
    print " если потом не запускается, то надо удалить сгенеренную модель:\n";
    print " rm ../lib/VOIS/Contragent/Schema/MainDB/Result/Thesaurus/Currency.pm\n\n";
    exit(1);
}

sub get_schema {
    my $connect = $module->connect();
    return $connect;
}

sub get_data_type {
    my $data_from_pg = shift;
    my $model_type = '';
    if ($data_from_pg eq 'character varying') {
        $model_type = 'text';
    } elsif ($data_from_pg eq 'text') {
        $model_type = 'text';
    } elsif ($data_from_pg eq 'uuid') {
        $model_type = 'uuid';
    } elsif ($data_from_pg eq 'date') {
        $model_type = 'date';
    } elsif ($data_from_pg eq 'json') {
        $model_type = 'text';
    } elsif ($data_from_pg eq 'smallint') {
        $model_type = 'type';
    } elsif ($data_from_pg eq 'integer') {
        $model_type = 'integer';
    } elsif ($data_from_pg eq 'numeric') {
        $model_type = 'integer';
    } elsif ($data_from_pg eq 'bigint') {
        $model_type = 'integer';
    } elsif ($data_from_pg eq 'double precision') {
        $model_type = 'float';
    } elsif ($data_from_pg eq 'float') {
        $model_type = 'float';
    } elsif ($data_from_pg eq 'boolean') {
        $model_type = 'boolean';
    } elsif ($data_from_pg =~ /timestamp/) {
        $model_type = 'integer';
    } else {
        return $data_from_pg;
    }
    print "$data_from_pg => $model_type\n";
    return $model_type;
}

sub get_description {
    my ($dbh, $shema, $table) = @_;
    my $sql = '
        SELECT a.attname,
          pg_catalog.format_type(a.atttypid, a.atttypmod),
          (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
           FROM pg_catalog.pg_attrdef d
           WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef),
          a.attnotnull, a.attnum,
          (SELECT c.collname FROM pg_catalog.pg_collation c, pg_catalog.pg_type t
           WHERE c.oid = a.attcollation AND t.oid = a.atttypid AND a.attcollation <> t.typcollation) AS attcollation,
          NULL AS indexdef,
          NULL AS attfdwoptions,
          a.attstorage,
          CASE WHEN a.attstattarget=-1 THEN NULL ELSE a.attstattarget END AS attstattarget, pg_catalog.col_description(a.attrelid, a.attnum)
        FROM pg_catalog.pg_attribute a
        WHERE a.attnum > 0 AND NOT a.attisdropped
        AND a.attrelid = 
        (
          SELECT c.oid
          FROM pg_catalog.pg_class c
               LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname ~ \'^({TAB})$\'
            AND n.nspname ~ \'^({SH})$\'
        )
        ORDER BY a.attnum
    ';

    $sql =~ s/{TAB}/$table/;
    $sql =~ s/{SH}/$shema/;

    my $dbq = $dbh->prepare($sql);
    $dbq->execute or die "Could not execute $sql:$!\n";
    my $hash = $dbq->fetchall_hashref('attname');
    $dbq->finish;
    return $hash;
}

# =[ main ]======================================
my $schema = get_schema;
$sql = "GRANT SELECT ON ".lc($table_schema).".".lc($table_name_original)." TO vois_contr";
$res = $schema->storage->dbh->do($sql);
$sql = "GRANT INSERT ON ".lc($table_schema).".".lc($table_name_original)." TO vois_contr";
$res = $schema->storage->dbh->do($sql);
$sql = "GRANT UPDATE ON ".lc($table_schema).".".lc($table_name_original)." TO vois_contr";
$res = $schema->storage->dbh->do($sql);
$sql = "GRANT DELETE ON ".lc($table_schema).".".lc($table_name_original)." TO vois_contr";
$res = $schema->storage->dbh->do($sql);

if (-f $model_path and $force_build ne '--force') {
    print "Model already exists! use force for rebuild: ./$0 --force\n";
    exit(1);
}

$sql = "
select table_catalog,
  table_schema,
  table_name,
  column_name,
  ordinal_position,
  is_nullable,
  data_type
from
  information_schema.columns
where
  table_schema='".lc($table_schema)."'
and
  table_name='".lc($table_name_original)."'
";

print "SQL => $sql\n";
my $data = $schema->storage->dbh->selectall_arrayref($sql) || die("Can't make sql: $!");
foreach my $row (@{$data}) {
    $database_structure{$row->[0]}{$row->[1]}{$row->[2]}{$row->[3]} =
        {
            'position'    => $row->[4],
            'is_nullable' => ($row->[5] eq "YES") ? 1 : 0,
            'data_type'   => $row->[6]
        };

}

my $DBI_template = '';

my $head = q[
package VOIS::{PROJECT}::Schema::MainDB::Result::{TABLE_SHEMA}::{TABLE_NAME};

use uni::perl   qw|:dumper|;
use lib::abs    qw| ../../../../../../../lib |;
use base        qw| VOIS::{PROJECT}::Schema::Class::Core |;

# uncomment this if you need use type. And add to column data => \%TYPE_NAME,
#our %TYPE_NAME = (
#    1 => "Юридическое лицо",
#);

#our %STATUS_NAME = (
#    1 => "Юридическое лицо",
#);
];

$head =~ s/{PROJECT}/$project_name/g;
$head =~ s/{TABLE_SHEMA}/$table_schema/g;
$head =~ s/{TABLE_NAME}/$table_name/g;

$DBI_template .= $head;

my $fields_head = "\n__PACKAGE__->table('".lc($table_schema).".".lc($table_name_original)."');
__PACKAGE__->add_columns(";

$DBI_template .= $fields_head;
foreach my $database (keys %database_structure) {
    print "Datbase => $database\n";
    foreach my $shema (keys %{$database_structure{$database}}) {
        print "shema => $shema\n";
        foreach my $table (keys %{$database_structure{$database}{$shema}}) {
            print "table => $table\n";
            my $dscription_hash = get_description($schema->storage->dbh, $shema, $table);
            my %fields = %{$database_structure{$database}{$shema}{$table}};
            my @fields_sorted_keys = sort {$fields{$a}{'position'} <=> $fields{$b}{'position'}} keys %fields;
            foreach my $field_name (@fields_sorted_keys) {
                print "field => $field_name\n";
                my $wo_add = 0;
                my $wo_edit = 0;
                my $data_type = get_data_type($fields{$field_name}{data_type});
                my $is_nullable = $fields{$field_name}{is_nullable};
                my $description = $dscription_hash->{$field_name}->{col_description};
                $description =~ s/[\r\n]/ /g;

                # can't edit this fields
                if ($field_name eq 'id' or $field_name eq 'ctime' or $field_name eq 'utime') {
                    $wo_add  = 1;
                    $wo_edit = 1;
                } else {
                    $wo_add  = 0;
                    $wo_edit = 0;
                }

                if ($description =~ /wo_add/) {
                    $wo_add = 1;
                }

                if ($description =~ /wo_edit/) {
                    $wo_edit = 1;
                }

                if ($field_name eq 'json_custom') {
                    $data_type = 'json';
                }

                if ($field_name eq 'status') {
                    $data_type = 'status';
                }

                # construct fields
                my $field = "
    '$field_name',
    {
        data_type      => '$data_type',
        is_nullable    => $is_nullable,
        wo_add         => ".($wo_add ? 1 : 0).",
        wo_edit        => ".($wo_edit ? 1 : 0).",
        note           => '".join(" ", $description)."',"
        .($data_type eq 'type'   ? "\n        ".'data           => \%TYPE_NAME,'   : '')
        .($data_type eq 'status' ? "\n        ".'data           => \%STATUS_NAME,' : '')."
    },";
                $DBI_template .= $field;
            }
        }
    }
}

my $footer = q[
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->inflate_json_column('json_custom');
__PACKAGE__->resultset_class('VOIS::{PROJECT}::Schema::Class::ResultSet');

#sub get_types  { \%TYPE_NAME   }
#sub get_status { \%STATUS_NAME }

sub validate_orderby {
    my ( $self, $order_by ) = @_;
    $order_by ||= "ctime:desc";
    $self->next::method($order_by);
}

sub hash_api_red {
    my $self = shift;
    my $hash = $self->next::method(@_);
    # uncomment this if you need use type
    #$hash->{'type_name'}   = $TYPE_NAME{$self->type};
    #$hash->{'status_name'} = $STATUS_NAME{$self->status};
    $hash;
}

1;
];

$footer =~ s/{PROJECT}/$project_name/g;

$DBI_template .= $footer;

unless (-d $model_dir) {
    print "create dir for model => $model_dir\n";
    make_path($model_dir) or die("Can't create path => $model_path");
}

open (my $df, ">$model_path") or die("Can't open for writeing => $model_path Reason: $!");
print $df $DBI_template;
close($df);

print "Done! See model:\n vim $model_path\n\n";