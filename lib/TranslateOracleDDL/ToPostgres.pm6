use v6;

class TranslateOracleDDL::ToPostgres {
    method TOP($/) {
        make $<sql-statement>>>.made.grep({ $_ }).join(";\n") ~ ";\n";
    }

    method sql-statement:sym<REM> ($/) {
        if $<string-to-end-of-line> {
            make "-- $<string-to-end-of-line>";
        } else {
            make '--';
        }
    }

    method sql-statement:sym<PROMPT> ($/) {
        if $<string-to-end-of-line> {
            make "\\echo $<string-to-end-of-line>";
        } else {
            make "\\echo";
        }
    }

    method sql-statement:sym<empty-line> ($/) { return Any; }

    method bigint ($/) {
        make $/ > 9223372036854775807
            ?? make "9223372036854775807"
            !! make ~ $/;
    }

    method sql-statement:sym<CREATE-SEQUENCE> ($/) {
        if $<create-sequence-clause>.elems {
            my @clauses = $<create-sequence-clause>.map({ .made // ~ $_ }).grep({ $_ });
            make "CREATE SEQUENCE $<entity-name> " ~ @clauses.join(' ');
        } else {
            make "CREATE SEQUENCE $<entity-name>";
        }
    }

    method create-sequence-clause:sym<START-WITH> ($/)  { make 'START WITH ' ~ $<bigint>.made }
    method create-sequence-clause:sym<INCREMENT-BY> ($/)  { make 'INCREMENT BY ' ~ $<bigint>.made }
    method create-sequence-clause:sym<MINVALUE> ($/)    { make 'MINVALUE ' ~ $<bigint>.made }
    method create-sequence-clause:sym<MAXVALUE> ($/)    { make 'MAXVALUE ' ~ $<bigint>.made }
    method create-sequence-clause:sym<CACHE> ($/)       { make 'CACHE ' ~ $<bigint>.made }
    method create-sequence-clause:sym<NOMINVALUE> ($/)  { make 'NO MINVALUE' }
    method create-sequence-clause:sym<NOMAXVALUE> ($/)  { make 'NO MAXVALUE' }
    method create-sequence-clause:sym<NOCYCLE> ($/)     { make 'NO CYCLE' }
    method create-sequence-clause:sym<NOCACHE> ($/)     { make '' }
    method create-sequence-clause:sym<ORDER> ($/)       { make '' }
    method create-sequence-clause:sym<NOORDER> ($/)     { make '' }

    method sql-statement:sym<CREATE-TABLE> ($/) {
        make "CREATE TABLE $<entity-name> ( " ~ $<create-table-column-list>.made ~ " )"
    }

    method create-table-column-list ($/) { make $<create-table-column-def>>>.made.join(', ') }
    method create-table-column-def ($/) {
        my @parts = ( $<identifier>, $<column-type>.made );
        @parts.push( $<create-table-column-constraint>>>.made ) if $<create-table-column-constraint>;
        make join(' ', @parts);
    }

    # data types
    method column-type:sym<VARCHAR2> ($/)   { make $<integer> ?? "VARCHAR($<integer>)" !! "VARCHAR" }

    my subset out-of-range of Int where { $_ < 0 or $_ > 38 };
    method column-type:sym<NUMBER-with-prec> ($/)     {
        given $<integer>.Int {
            when 1 ..^ 3    { make 'SMALLINT' }
            when 3 ..^ 5    { make 'SMALLINT' }
            when 5 ..^ 9    { make 'INT' }
            when 9 ..^ 19   { make 'BIGINT' }
            when 19 .. 38   { make "DECIMAL($<integer>)" }
            when out-of-range { die "Can't handle NUMBER($<integer>): Out of range 1..38" }
            default         { make 'INT' }
        }
    }
    method column-type:sym<NUMBER-with-scale> ($/) {
        my ($precision, $scale) = $<integer>;
        die "Can't handle NUMBER($precision): Out of range 1..38" if $precision.Int ~~ out-of-range;

        make "DECIMAL($precision,$scale)";
    }

    method column-type:sym<DATE> ($/)       { make "TIMESTAMP(0)" }
    method column-type:sym<TIMESTAMP> ($/)  { make "TIMESTAMP($<integer>)"; }
    method column-type:sym<CHAR> ($/)       { make "CHAR($<integer>)" }
    method column-type:sym<BLOB> ($/)       { make 'BYTEA' }
    method column-type:sym<CLOB> ($/)       { make 'TEXT' }
    method column-type:sym<LONG> ($/)       { make 'TEXT' }
    method column-type:sym<FLOAT> ($/)      { make 'DOUBLE PRECISION' }
    method column-type:sym<INTEGER> ($/)    { make 'DECIMAL(38)' }

    method create-table-column-constraint:sym<NOT-NULL> ($/) { make 'NOT NULL' }
    method create-table-column-constraint:sym<PRIMARY-KEY> ($/) { make 'PRIMARY KEY' }
}

