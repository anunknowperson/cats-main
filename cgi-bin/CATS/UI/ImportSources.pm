package CATS::UI::ImportSources;

use strict;
use warnings;

use CATS::Constants;
use CATS::DB;
use CATS::Globals qw($is_jury $t $uid);
use CATS::ListView;
use CATS::Messages qw(res_str);
use CATS::Output qw(init_template url_f url_f_cid);
use CATS::References;

sub import_sources_frame {
    my ($p) = @_;
    init_template($p, 'import_sources.html.tt');
    my $lv = CATS::ListView->new(web => $p, name => 'import_sources', url => url_f('import_sources'));
    $lv->default_sort(0)->define_columns([
        { caption => res_str(625), order_by => '2', width => '30%' },
        { caption => res_str(642), order_by => '3', width => '30%' },
        { caption => res_str(641), order_by => '4', width => '30%' },
        { caption => res_str(643), order_by => '5', width => '10%' },
    ]);
    $lv->define_db_searches([ qw(PS.id guid stype code fname problem_id title contest_id) ]);

    my $sth = $dbh->prepare(q~
        SELECT ps.id, psl.guid, psl.stype, de.code,
            (SELECT COUNT(*) FROM problem_sources_imported psi WHERE psl.guid = psi.guid) AS ref_count,
            psl.fname, ps.problem_id, p.title, p.contest_id,
            (SELECT CA.is_jury FROM contest_accounts CA
                WHERE CA.account_id = ? AND CA.contest_id = p.contest_id)
            FROM problem_sources ps
            INNER JOIN problem_sources_local psl ON psl.id = ps.id
            INNER JOIN default_de de ON de.id = psl.de_id
            INNER JOIN problems p ON p.id = ps.problem_id
            WHERE psl.guid IS NOT NULL ~ . $lv->maybe_where_cond . $lv->order_by);
    $sth->execute($uid // 0, $lv->where_params);

    my $fetch_record = sub {
        my $f = $_[0]->fetchrow_hashref or return ();
        return (
            %$f,
            stype_name => $cats::source_module_names{$f->{stype}},
            href_problems => url_f_cid('problems', cid => $f->{contest_id}),
            href_source => url_f('download_import_source', psid => $f->{id}),
        );
    };

    $lv->attach($fetch_record, $sth);

    $t->param(submenu => [ CATS::References::menu('import_sources') ]) if $is_jury;
}

sub download_frame {
    my ($p) = @_;
    $p->{psid} or return;
    # Source encoding may be arbitrary.
    local $dbh->{ib_enable_utf8} = 0;
    my ($fname, $src) = $dbh->selectrow_array(q~
        SELECT fname, src FROM problem_sources_local WHERE id = ? AND guid IS NOT NULL~, undef,
        $p->{psid}) or return;
    $p->print_file(
        content_type => 'text/plain',
        file_name => $fname,
        content => Encode::encode_utf8($src));
}

1;
